class ZabbixAgentPlugin

  attr_accessor :name
  
  
  def call_check_ok_to_load
    result = check_ok_to_load
    @ok = result.nil?
    result
  end
  
  #return nil of all ok, or an error message
  def check_ok_to_load
    nil
  end
  
  def ok?
    @ok
  end
  
  def set_daemon(daemon)
    @daemon = daemon
  end
    
  def logger
    @daemon.logger
  end
  
  #polling rate in seconds 
  def polling_rate
    5
  end
  
  def should_run_polling?
    @last_polled.nil? || Time.now.to_i > @last_polled + polling_rate
  end
  
  def run_polling
    @last_polled = Time.now.to_i
    begin
      poll
      if !@ok
        logger.info("#{self.name} now polling") #report that the plugin is now working again...
        @ok = true
      end
    rescue Exception=>e
      if @ok
        #first exception.. report it...
        @ok = false
        raise
      else
        logger.debug("Error polling #{name}: #{e.message}")
      end
    end
  end
  
  #override this method
  def poll
    raise "poll method not implemented in #{self.class.name}"
  end
  
  #override this method
  #return a 2d array of data to send in [[[key],[value]],[[key],[value]]] format
  def prepare_report
    raise "prepare_report method not implemented in #{self.class.name}"
  end
  
  
end
