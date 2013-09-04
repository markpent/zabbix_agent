require 'rubygems'
gem 'passenger'
require 'phusion_passenger'
require 'phusion_passenger/platform_info'
require 'phusion_passenger/admin_tools/server_instance'
require 'nokogiri'

class ZabbixAgentPassenger < ZabbixAgentPlugin
  def initialize(config)
    reset_data
  end
  
  def check_ok_to_load
    server_instances = PhusionPassenger::AdminTools::ServerInstance.list
    if server_instances.empty?
      return "Phusion Passenger doesn't seem to be running."
    elsif server_instances.size > 1
      return "It appears that multiple Passenger instances are running."
    else
      #make sure we can connect
      begin
        server_instances.first.connect(:passenger_status) do
          general_info = server_instances.first.status
        end
      rescue PhusionPassenger::AdminTools::ServerInstance::RoleDeniedError
        return "You do not have permission to query the passenger instance"
      rescue SystemCallError => e
        return "Cannot query status for Phusion Passenger instance #{server_instances.first.pid}: #{e.to_s}"
      end
    end
    nil
  end
  
  def reset_data
    @poll_data = {:active=>0, :queue=>0, :max_active=>0, :max_queue=>0}
    @poll_count = 0
  end
  
  def poll
    logger.debug "polling passenger"
    server_instances = PhusionPassenger::AdminTools::ServerInstance.list
    if server_instances.empty?
      raise "Phusion Passenger doesn't seem to be running."
    elsif server_instances.size > 1
      raise "It appears that multiple Passenger instances are running."
    else
      #make sure we can connect
      begin
        server_instances.first.connect(:passenger_status) do
          general_info = server_instances.first.xml
          doc = Nokogiri::XML(general_info)
          active = doc.at("/info/active").content.to_s.to_i
          @poll_data[:active] += active
          @poll_data[:max_active] = active if @poll_data[:max_active] < active
          queue = doc.at("/info/global_queue_size").content.to_s.to_i
          @poll_data[:queue] += queue
          @poll_data[:max_queue] = queue if @poll_data[:max_queue] < queue
          @poll_count += 1
        end
      rescue PhusionPassenger::AdminTools::ServerInstance::RoleDeniedError
        raise "You do not have permission to query the passenger instance"
      rescue SystemCallError => e
        raise "Cannot query status for Phusion Passenger instance #{server_instances.first.pid}: #{e.to_s}"
      end
    end
  end
  
  def prepare_report
    result = []
    unless @poll_count == 0
      result << ["passenger.active",  (@poll_data[:active].to_f / @poll_count.to_f).to_i]
      result << ["passenger.max.active",  @poll_data[:max_active]]
      result << ["passenger.queue",(@poll_data[:queue].to_f / @poll_count.to_f).to_i]
      result << ["passenger.max.queue",  @poll_data[:max_queue]]
    end
    reset_data
    result
  end

end


ZabbixAgentPluginManager.register(:passenger, ZabbixAgentPassenger)
