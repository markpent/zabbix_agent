require "socket" 
require "csv"

class ZabbixAgentHaProxy < ZabbixAgentPlugin
  def initialize(config)
    @backends = config[:backends] == true
    @frontends = config[:frontends] == true
    @servers = config[:servers] == true
    @attributes = config[:attributes]
    @socket_file = config[:socket_file].nil? ? "/var/run/haproxy.sock" : config[:socket_file]
    reset_data
    #make sure we can access the socket file
    begin
      UNIXSocket.open(@socket_file) {}
    rescue Exception=>e
      raise "unable to access stats socket file #{@socket_file}: #{e.message}"
    end
    #puts self.inspect
  end
  
  AVERAGE_ATTRIBUTES = {
    "qcur"=>true,
    "scur"=>true,
  }
  
  
  def reset_data
    @poll_data = {}
    @poll_count = 0
  end
  
  def poll
    logger.info "polling ha_proxy"
    @poll_count += 1
    data = get_stats_data
    extract_stats(data)
  end
  
  def get_stats_data
    data = UNIXSocket.open(@socket_file) do |f|
      f.send "show stat\n", 0
      buf = ""
      stripped_comment = false
      line = f.recv(1000)
      while !line.nil? && line.length > 0
        unless stripped_comment
          line = line[2, line.length - 2 ]
          stripped_comment = true                                                                                                                                                                                       
        end                                                                                                                                                                                                                   
        buf << line                                                                                                                                                                                                           
        line = f.recv(1000)                                                                                                                                                                                                   
      end                                                                                                                                                                                                                           
      buf                                                                                                                                                                                                                           
    end                                                                                                                                                                                                                                   
    data                                                                                                                                                                                                                                                                                                                                                                                                                                                               
  end                                                                                                                                                                                                                                           
                                                                                                                                                                                                                                                  
  def extract_stats(raw_data)                                                                                                                                                                                                                     
    #cross version (clunky) way                                                                                                                                                                                                           
    rows = CSV.parse(raw_data)                                                                                                                                                                                                            
    #first line is column headings...                                                                                                                                                                                                     
    cols = {}                                                                                                                                                                                                                             
    heading_row = rows.shift                                                                                                                                                                                                              
    heading_row.each_with_index { |col, idx| cols[col] = idx }                                                                                                                                                                            
    for row in rows
      name = row[cols["pxname"]]
      server = row[cols["svname"]]
      if server == "BACKEND" 
        next if !@backends
      elsif server == "FRONTEND"
        next if !@frontends
      else
        next if !@servers
      end
      data_name = "#{name}.#{server}"
      poll_data = @poll_data[data_name]
      @poll_data[data_name] = poll_data = {} if poll_data.nil?
      @attributes.each do |code|
        if AVERAGE_ATTRIBUTES[code]
          poll_data[code] = 0 if poll_data[code].nil?
          poll_data[code] += row[cols[code]].to_i
        else
          poll_data[code] = row[cols[code]]
        end
      end
    end
  end
    

  
  def prepare_report
    result = []
    @poll_data.each do |server_name, values|
      #set averages
      AVERAGE_ATTRIBUTES.each do |code|
        if values[code]
          values[code] = values[code].to_f / @poll_count.to_f
        end
      end
      values.each do |key, value|
        result << ["#{server_name}.#{key}", value.to_s]
      end
    end
    reset_data
    #reset the max counters
    data = UNIXSocket.open(@socket_file) do |f|
      f.send "clear counters\n", 0
    end
    result
  end

end


ZabbixAgentPluginManager.register(:ha_proxy, ZabbixAgentHaProxy)
