#!/usr/bin/ruby
# == Monstar: Mongrel (force)restart on source changes
# * restart the specific Mongrel server upon source changes...
# * all the scripts file ctime is monitored.
# * in fact, this script will restart any app you want. I used it for a Mongrel process. Just set the app variable and pass it into the class.
# * script version: 0.9
# * author: pedro mg (pedro.mota@gmail.com)
# * blog: http://blog.tquadrado.com
# * this script is licensed under a Ruby license

require 'optparse'

class Monstar

  # Initial files status, stored in an array
  def initialize(app, exec, interval, files)
    @app  = app.nil? ? nil : app.join(' ') 
    @exec = exec.nil? ? nil : exec.join(' ') 
    @i = interval
    @files = files
    @f0 = []
    @files.each { |f| @f0 << file_stat(f) }
  end

  # Get the ctime (change time stamp) info for the arg file
  def file_stat(f)
    File.open(f, 'r').ctime 
  end

  # fork/spawn a new process to run the:
  # ruby script if -a
  # system script if -e
  def load_app
    if !@app.nil? 
      @pid = Process.fork { load(@app) }
    else
      @pid = Process.spawn("#{@exec.to_s}")
    end
  end

  # kill the process previously forked, and wait its termination so that
  # new Mongrel instance starts fine without address/port colision
  def kill_app
    Process.kill("INT", @pid)
    Process.wait(@pid)
  end
          
  # monitor loop, that checks the condition (time interval). Could be a new thread, 
  # could be a forked process, but for simplicity its the main thread.
  def start
    load_app
    loop do
      sleep(@i)
      f1 = Array.new
      @files.each { |f| f1 << file_stat(f) } 
      if !(f1 == @f0)
        puts ("MONSTAR::File change... will restart #{@app} NOW (#{Time.now.to_s})")
        puts "  * file change detected !!!"
        # shut the process down
        kill_app
        puts "  * app process killed..."
        @f0 = f1
        puts "  * file ctime stamp stored... restarting #{@app}"
        # load a new process
        load_app
        puts "  * MONSTAR:: #{@app} restarted!"
      end
    end
    Process.waitall
  end
end


# ----
# if you want to use this class, as a running shell command, use the code below:
begin
  # from v0.5, option parsing was added. 
  # I really needed it since I added options to the scripts I was monitoring...
  options = {}
  # defaults
  options[:interval] = 3
  OptionParser.new do |opts|
    opts.on("-a", "--app SCRIPT.RB,PARAMS,...", Array) {|v| options[:app] = v }
    opts.on("-e", "--exec SCRIPT,PARAMS...", Array) {|v| options[:exec] = v }
    opts.on("-i", "--interval VAL", Integer) {|v| options[:interval] = v }
    opts.on("-f", "--files FILE,FILE1,...", Array) {|v| options[:files] = v }
    opts.on("-h", "--help") {|v| puts opts; exit }
  end.parse!

  # extra verifications: interval should_not be < 1; files must exist;
  raise if options[:interval] < 1
  options[:files].each { |f| raise if !File.exist?(f) }
  puts "MONSTAR:: monitor source changes and start new process for app"
  puts "  - script  : #{options[:app].join(' ')}" if !options[:app].nil?
  puts "  - exec    : #{options[:exec].join(' ')}"if !options[:exec].nil?
  puts "  - interval: #{options[:interval]} secs."
  puts "  - files: #{options[:files].join(' ')}"if !options[:files].nil?

  m = Monstar.new(options[:app], options[:exec], options[:interval], options[:files])
  m.start
 rescue => e
  puts "... please try some help: monstar.rb -h"
  # if you want some verbose dump, uncheck the follow line:
  # puts "HALT::DUMP => #{e.backtrace.join('\n')}"
  exit
end


