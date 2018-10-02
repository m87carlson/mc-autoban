#!/usr/bin/env ruby
require 'time'
require 'pry'
require 'file-tail'

# open log file
# tail latest.log
#
# watch for patterns:
#
#[15:40:10] [Server thread/INFO]: [treesnake163: Unbanned canoo30]
#[15:44:19] [Server thread/INFO]: [treesnake163: Made canoo30 a server operator]
#
# { "violation" => { "type": "unban", "offender": "usera", "target": "userb" } }
RCON_PASS=ENV['RCON_PASS']
RCON_HOST=ENV['RCON_HOST']
RCON_PORT=ENV['RCON_PORT']

puts RCON_HOST
puts RCON_PORT

LATEST_FILE = "/var/log/minecraft-server/latest.log"
OFFENSES = /Unbanned|a server operator/

def watch_for(file, pattern)
  # Replace -n0 with -n+1 if you want to read from the beginning of file
  puts "watching #{file}..."
  f = IO.popen(%W[tail -f -n0 #{file}])
  loop do
    select([f])
    while line = f.gets
      ban(violators(line)) if line =~ pattern
    end
  end
end

def violators(line)
  if line =~ /Unbanned/
    offender = line[/.*\[(.*)\]/,1].sub(':','').split()[0]
    target = line[/.*\[(.*)\]/,1].sub(':','').split()[-1]
    return {"violation"=>{ "type"=> "unban", "offender"=>offender, "target"=>target}} unless offender =~ /[Rr]con/ # RCon can do stuff
  elsif line=~ /a server operator/
    offender = line[/.*\[(.*)\]/,1].sub(':','').split()[0]
    target = line[/.*\[(.*)\]/,1].sub(':','').split()[2]
    return {"violation"=>{ "type"=>"admin", "offender"=>offender, "target"=>target}} unless offener =~ /[Rr]on/
  else
    puts "unknown violation pattern: #{line}"
  end
end

def ban(obj)
  case obj["violation"]['type']
  when "unban"
    puts "Banning #{obj['violation']['offender']} and #{obj['violation']['target']} for offense: #{obj['violation']['type']}"
    cmd = %x{ mcrcon -cc -H #{RCON_HOST} -P #{RCON_PORT} -p #{RCON_PASS} "ban #{obj['violation']['offender']}" }
    cmd = %x{ mcrcon -cc -H #{RCON_HOST} -P #{RCON_PORT} -p #{RCON_PASS} "ban #{obj['violation']['target']}" }
  when "admin"
    puts "De-oping #{obj['violation']['offender']} and #{obj['violation']['target']} for offense: #{obj['violation']['type']}"
    cmd = %x{ mcrcon -cc -H #{RCON_HOST} -P #{RCON_PORT} -p #{RCON_PASS} "deop #{obj['violation']['offender']}" }
    cmd = %x{ mcrcon -cc -H #{RCON_HOST} -P #{RCON_PORT} -p #{RCON_PASS} "deop #{obj['violation']['target']}" }
  end
end  

watch_for(LATEST_FILE, OFFENSES)
