class ZabbixAgentPluginManager
  @@plugins = {} 
  def self.register(name, clazz)
    @@plugins[name] = clazz
  end
  
  def self.get_plugin(name, config)
    if @@plugins[name].nil?
      puts "Unable to load plugin #{name}"
      return nil
    end
    begin
      @@plugins[name].new(config)
    rescue Exception=>e
      puts "Error loading plugin #{name}: #{e.message}"
      return nil
    end
  end

end
