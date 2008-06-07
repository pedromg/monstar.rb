#!/usr/bin/ruby
# == Monstar: Mongrel (force)restart on source changes
# * restart the specific Mongrel server upon source changes...
# * all the scripts file ctime is monitored.
# * in fact, this script will restart any app you want. I used it for a Mongrel process. Just set the app variable and pass it into the class.
class Monstar

  # Initial files status, stored in an array
  def initialize(files, app, interval)
    @files = files
    @app = app
    @i = interval
    @f0 = []
    @files.each { |f| @f0 << file_stat(f) }
  end

  # Get the ctime (change time stamp) info for the arg file
  def file_stat(f)
    File.open(f, 'r').ctime 
  end

  # fork a new process to run the ruby script
  def load_app
    @pid = Process.fork { load(@app) }
  end

  # kill the process previously forked, and wait its termination so that
  # new Mongrel instance starts fine without colision
  def kill_app
    Process.kill("KILL", @pid)
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
  # ruby app to be run
  app = $*[0]
  # interval in seconds to use for file change checks
  interval = $*[1].to_i
  # array of files to be monitored
  files = $*[2..$*.length-1]
  # extra verifications: interval should_not be < 1; files must exist;
  raise if interval < 1
  files.each { |f| raise if !File.exist?(f) }
  puts "MONSTAR:: monitor source changes and start new process for app"
  puts "  - script  : #{app}"
  puts "  - interval: #{interval} secs."
  puts "  - files: #{files.join(' ')}"

  m = Monstar.new(files, app, interval)
  m.start
rescue => e
  puts "HALT :: "
  puts "  - usage: monstar.rb <script.rb> <interval> <space separated files>"
  puts e.backtrace.join("\n")
  exit
end


