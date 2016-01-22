# -*- coding: utf-8 -*-
$LOAD_PATH << File.dirname(__FILE__)

require 'active_support/time'
require 'sinatra'
require 'sinatra/multi_route'
require 'eventmachine'
require 'pp'
require 'pg'
require 'open-uri'
require 'uri'
require 'json'

Time.zone = "Asia/Tokyo"

uri = URI.parse(ENV['DATABASE_URL'])
con = PG::connect(host: uri.host, user: uri.user, password: uri.password, port: uri.port, dbname: uri.path[1..-1])

res = begin
  con.exec("SELECT counter, updated_at FROM counters")
rescue PG::UndefinedTable => e
  con.exec("CREATE TABLE counters (counter INT NOT NULl, updated_at timestamp default NULL)")
  con.exec("INSERT INTO counters (counter, updated_at) values (0, now())")
  con.exec("SELECT counter, updated_at FROM counters")
end

counter = res[0]["counter"].to_i
updated_at = Time.zone.parse(res[0]["updated_at"] + " UTC")
stated_at = Time.zone.now

def exit?
  sleep_time = [{start: "23:50", stop: "24:00"},
                {start: "00:00", stop: "06:30"}]
  Time.zone = "Asia/Tokyo"
  now = Time.zone.now
  sleep_time.each do |sl|
    t1 = Time.zone.parse(sl[:start])
    t2 = Time.zone.parse(sl[:stop])
    if t1 <= now && now < t2
      return true
    end
  end
  false
end

EM::defer do
  loop do
    next if exit?

    sleep 3.minutes
    counter += 1
    con.exec("UPDATE counters SET counter=#{counter}, updated_at=now()")

    # polling self to prevent sleep
    open("https://db-test10.herokuapp.com/heartbeat")
  end
end

get '/heartbeat' do
  "OK"
end

get '/force-sync' do
  "OK"
end

post '/out-going' do
  #content_type 'application/json; charset=utf-8'
  #p request.body.read
  #p params[:text]
  #text = params[:text]
  #if text =~ /^今の天気/
  #  cw = weather.current_wheather
  #  response = cw ? (cw.fine? ? "晴れ" : "雨") : "不明"
  #elsif text =~ /^今の通知は？/
  #  response = weather.notification_message(ignore_sended: true)
  #elsif text =~ /^debug|デバッグ/
  #  json = {now: Time.now.to_s, last_synced_at: last_synced_at, counter: counter, weather: weather.weather, notifications: weather.notifications}
  #  response = PP.pp(json, '')
  #end
  #{text: response}.to_json
end


# For debug
get '/debug' do
  {counter: counter, updated_at: updated_at, stated_at: stated_at}.to_json.to_s
end
