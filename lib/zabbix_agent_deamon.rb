require 'yaml'
require 'optparse'
require 'logger'

class ZabbixAgentDaemon
  
  attr_accessor :logger
  
  def initialize
    @options = {
      :config=>"config.yml",
      :daemonize=>false,
      :command=>:start,
      :pid_file=>"/var/run/zabbix_agent.pid"
    }
    @config = {
      :plugins=>{
        :ha_proxy=>{
        
        },
        :passenger=>{
        
        }
      },
      :reporting_rate=>5 * 60, #5 minutes
      :zabbix_config=>"/etc/zabbix/zabbix_agentd.conf",
      :zabbix_sender=>"/usr/bin/zabbix_sender"
    }
    @plugins = []
    @running = true
  end
  
  def run
    return if !load_options
    if @options[:command] == :stop
      stop_daemon
      return
    end
    
    return if !load_config
    return if !load_plugins
    init_logging
    trap_signals
    if @options[:daemonize]
      return if !daemonize
    end
    #only get here if not running as daemon
    poll
  end
  
  def load_options
    argv = ARGV.clone
    cmd = argv.shift
    
    if cmd.nil? || cmd[0,1] == "-"
      argv.unshift cmd
      cmd = nil
    end
    
    @options[:command] = cmd.nil? ? :start : cmd.downcase.intern

    OptionParser.new do |opts|
      opts.banner = "Usage: zabbix_agent command [options]"
      opts.on("-c", "--config PATH", "Configuration Path") do |cp|
        @options[:config] = cp
      end
      opts.on("-l", "--logfile [PATH]", "Logfile Path") do |lf|
        @options[:log_file] = lf
      end
      opts.on("-v", "--loglevel [LEVEL]", "Log Level") do |ll|
        @options[:log_level] = ll
      end
      opts.on("-p", "--pidfile [PATH]", "Pid file Path (/var/run/zabbix_agent.pid)") do |pf|
        @options[:pid_file] = pf
      end
      opts.on("-d", "--daemonize", "Run as a daemon") do
        @options[:daemonize] = true
      end
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        return false
      end
    end.parse!(argv)
    true
  end
  
  
  def load_config
    full_path = File.expand_path(@options[:config])
    if !File.exist?(full_path)
      puts "Warning: configuration file #{full_path} is missing. Using default configuration."
      return true
    end
    raw_config = {}
    begin
      raw_config = YAML.load_file(full_path)
    rescue Exception=>e
      puts "Failed to load configuration file '#{full_path}': #{e.message}'"
      return false
    end
    @config.update(raw_config)
    true
  end
  
  def load_plugins
    @config[:plugins].each do |plugin_name, plugin_config|
      next if plugin_config[:disabled] == true
      plugin = ZabbixAgentPluginManager.get_plugin(plugin_name, plugin_config)
      return false if plugin.nil?
      plugin.set_daemon(self)
      @plugins << plugin
    end
    true
  end
  
  def daemonize
    ZabbixAgentDaemonizer.daemonize(self, @options)
  end
  
  def stop_daemon
    ZabbixAgentDaemonizer.stop_pid(@options)
  end
  
  def trap_signals
    Signal.trap("TERM") do
      logger.warn "Terminating..."
      @running = false
    end
    Signal.trap("INT") do
      logger.warn "Terminating..."
      @running = false
    end
  end
  
  def set_logging_level
    if @options[:log_level].nil? || @options[:log_level].strip.length == 0
      @options[:log_level] = "info" 
    else
      @options[:log_level] = @options[:log_level].to_s.downcase
    end
    case @options[:log_level]
    when 'debug'
      @logger.level = Logger::DEBUG
    when 'info'
      @logger.level = Logger::INFO
    when 'warn'
      @logger.level = Logger::WARN
    when 'error'
      @logger.level = Logger::ERROR
    when 'fatal'
      @logger.level = Logger::FATAL
    else
      puts "Unknown logging level: #{@options[:log_level]}"
      @logger.level = Logger::WARN
    end
  end
  
  def init_logging
    unless @options[:log_file].nil? 
      @options[:log_file] = full_path = File.expand_path(@options[:log_file])
      begin
        @logger = Logger.new(full_path, "daily")
        set_logging_level
      rescue Exception=>e
        puts "Error initializing log file #{path}: #{e.message}"
      end
    end
    if @logger.nil?
      #just make a fallback logger...
      if @options[:daemonize]
        @logger = Logger.new($stderr)
        @logger.level = Logger::FATAL
      else
        @logger = Logger.new($stdout)
        set_logging_level
      end
    end
    @logger.formatter = Proc.new { |severity, time, progname, msg|  "#{time.strftime('%c')}: #{severity} - #{msg}\n" }
  end
  
  def poll
    logger.info "Beginning Polling with reporting interval of #{@config[:reporting_rate]} seconds"
    last_reported = Time.now.to_i
    while @running
      for plugin in @plugins
        begin
          plugin.run_polling if plugin.should_run_polling?
        rescue Exception=>e
          logger.error("Error running plugin #{plugin.name}: #{e.message}")
          logger.debug(e.backtrace.join("\n"))
        end
      end
      if Time.now.to_i > last_reported + @config[:reporting_rate]
        report
        last_reported = Time.now.to_i
      end
      sleep(2)
    end
  end
  
  def report
    logger.info("Preparing report")
    report_data = []
    for plugin in @plugins
      begin
        report_data += plugin.prepare_report
      rescue Exception=>e
        logger.error("Error preparing report for plugin #{plugin.name}: #{e.message}")
        logger.debug(e.backtrace.join("\n"))
      end
    end
    unless report_data.empty?
      begin
        path = "/tmp/ha_stats_#{Time.now.to_i}.txt"
        File.open(path, "w") do |f|
          for row in report_data
            f.puts("- #{row[0]} #{row[1]}")
          end
        end
        if @options[:command] == :dump
          logger.fatal "Zabbix Data File dumped to #{path}"
          exit!
        end
          
        #call zabbix sender
        result = %x[#{@config[:zabbix_sender]} -c #{@config[:zabbix_config]} -i #{path} 2>&1]
        logger.info("Sent data to zabbix server with result: #{result}")
        File.delete(path)
      rescue Exception=>e
        logger.error("Exception sending report: #{e.message}")
        logger.error(e.backtrace.join("\n"))
      end
    end
  end

end
