class ZabbixAgentPassenger < ZabbixAgentPlugin
  def initialize(config)
    
  end
  
  def poll
    logger.info "polling passenger"
  end
  
  def prepare_report
    []
  end

end


ZabbixAgentPluginManager.register(:passenger, ZabbixAgentPassenger)
