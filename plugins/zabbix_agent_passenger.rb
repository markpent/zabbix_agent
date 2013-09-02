require 'rubygems'
gem 'passenger'
require 'phusion_passenger'
require 'phusion_passenger/platform_info'
require 'phusion_passenger/admin_tools/server_instance'
require 'nokogiri'

class ZabbixAgentPassenger < ZabbixAgentPlugin
  def initialize(config)
    server_instances = PhusionPassenger::AdminTools::ServerInstance.list
		if server_instances.empty?
			raise "Phusion Passenger doesn't seem to be running."
		elsif server_instances.size > 1
			raise "It appears that multiple Passenger instances are running."
		else
		  #make sure we can connect
		  begin
		    server_instances.first.connect(:passenger_status) do
		      general_info = server_instances.first.status
		    end
		  rescue PhusionPassenger::AdminTools::ServerInstance::RoleDeniedError
		    raise "You do not have permission to query the passenger instance"
		  rescue SystemCallError => e
		    raise "Cannot query status for Phusion Passenger instance #{server_instances.first.pid}: #{e.to_s}"
		  end
		end
		reset_data
  end
  
  def reset_data
    @poll_data = {:active=>0, :queue=>0}
    @poll_count = 0
  end
  
  def poll
    logger.info "polling passenger"
    server_instances = PhusionPassenger::AdminTools::ServerInstance.list
		if server_instances.empty?
			logger.error "Phusion Passenger doesn't seem to be running."
		elsif server_instances.size > 1
			logger.error "It appears that multiple Passenger instances are running."
		else
		  #make sure we can connect
		  begin
		    server_instances.first.connect(:passenger_status) do
		      general_info = server_instances.first.xml
		      doc = Nokogiri::XML(general_info)
		      @poll_data[:active] += doc.at("/info/active").content.to_s.to_i
		      @poll_data[:queue] += doc.at("/info/global_queue_size").content.to_s.to_i
		      @poll_count += 1
		    end
		  rescue PhusionPassenger::AdminTools::ServerInstance::RoleDeniedError
		    logger.error "You do not have permission to query the passenger instance"
		  rescue SystemCallError => e
		    logger.error "Cannot query status for Phusion Passenger instance #{server_instances.first.pid}: #{e.to_s}"
		  end
		end
  end
  
  def prepare_report
    result = []
    unless @poll_count == 0
      result << ["passenger.active",  (@poll_data[:active].to_f / @poll_count.to_f).to_i]
      result << ["passenger.queue",(@poll_data[:queue].to_f / @poll_count.to_f).to_i]
    end
    reset_data
    result
  end

end


ZabbixAgentPluginManager.register(:passenger, ZabbixAgentPassenger)
