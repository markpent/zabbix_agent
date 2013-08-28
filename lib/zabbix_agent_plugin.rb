class ZabbixAgentPlugin

  attr_accessor :name
  
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
    poll
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
