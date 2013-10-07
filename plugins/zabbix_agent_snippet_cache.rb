

class ZabbixAgentSnippetCache < ZabbixAgentPlugin
  def initialize(config)
    begin
      require config[:require]
    rescue Exception=>e
      raise "Unable to load snippet_cache client from '#{config[:require]}': #{e.message}"
    end
    reset_data
  end
  
  def check_ok_to_load
    client = SnippetCache.new('127.0.0.1', 8001, false, false, logger)
    stats = client.get_stats
    
    if stats.nil? || stats.empty?
      return "Unable to get stats."
    end
    nil
  end
  
  AVERAGE_ATTRIBUTES = {
    "qcur"=>true,
    "scur"=>true,
    "act"=>:backend
  }
  
  
  def reset_data
    @poll_data = {}
    @poll_count = 0
  end
  
  def poll
    logger.debug "polling snippet cache"
    client = SnippetCache.new('127.0.0.1', 8001)
    stats = client.get_stats
    raise "Unable to get stats" if stats.nil? || stats.empty?
      
    stats.each do |key, value|
      if AVERAGE_ATTRIBUTES[key] == true
        @poll_data[key] = 0 if @poll_data[key].nil?
        @poll_data[key] += value.to_i
      else
        @poll_data[key] = value
      end
    end
    @poll_count += 1
  end
  
  def prepare_report
    result = []
    @poll_data.each do |key, value|
      #set averages
      if AVERAGE_ATTRIBUTES[key] == true
        value = value.to_f / @poll_count.to_f
      end
      result << ["sc." + key.to_s, value.to_s]
    end
    reset_data
    result
  end

end


ZabbixAgentPluginManager.register(:snippet_cache, ZabbixAgentSnippetCache)
