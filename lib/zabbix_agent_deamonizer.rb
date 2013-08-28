module ZabbixAgentDaemonizer

  def self.get_pid(options)
    sPid = nil
    begin
      sPid = File.open(options[:pid_file]) { |f|
        f.read
      }
    rescue
      return nil
    end
    return nil if sPid.nil? || sPid.to_i == 0
    nPid = sPid.to_i
    begin
      #check process is actually running
      Process.kill(0, nPid)
      return nPid
    rescue
      return nil
    end
  end
  
  def self.check_not_running(options)
    proc_id = get_pid(options)
    unless proc_id.nil?
      puts "Process #{proc_id} already running"
      return false
    end
    true
  end
  
  def self.stop_pid(options)
    proc_id = get_pid(options)
    unless proc_id.nil?
      begin
        Process.kill(15, proc_id) 
      rescue 
        #dont care... the process may have died already?
      end
      count = 0
      while get_pid(options) && count < 10
        puts "Waiting..."
        sleep(1)
      end
      kill_pid(options) #make sure
    end
  end
  
  def self.kill_pid(options)
    proc_id = get_pid(options)
    begin
      Process.kill(9, proc_id) unless proc_id.nil?
    rescue 
      #dont care... the process may have died already?
    end
  end
  
  def self.write_pid(daemon, options)
    proc_id = Process.pid
    begin
      File.open(options[:pid_file], "w") { |f|
        f.write(proc_id.to_s)
      }
    rescue Exception=>e
       daemon.logger.error "Unable to write to pid file #{options[:pid_file]}: #{e.message}"
    end
  end
  
  def self.remove_pid(options)
    begin
      File.delete(options[:pid_file])
    rescue 
    end
  end
  
  def self.daemonize(daemon, options)
    fork {
      stdin = open '/dev/null', 'r'
      stdout = open '/dev/null', 'w'
      stderr = open '/dev/null', 'w'
      STDIN.reopen stdin
      STDOUT.reopen stdout
      STDERR.reopen stderr
      fork {
        write_pid(daemon, options)
        #daemon.init_logging #reopen files
        daemon.poll
      }.and exit!
    }
    false
  end

end
