require 'resolv-replace'

module HealthCheck
  class HealthCheckService
    extend EnvConfigurations
    if Rails.env == 'test'
      HEALTH_CHECK_CONFIG = {}
    elsif ENV['FETCH_ENVS_FROM_REMOTE_URL'] == 'true'
      HEALTH_CHECK_CONFIG = JSON.parse(ENV['HEALTH_CHECK_CONFIG'])
    else
      HEALTH_CHECK_CONFIG = YAML.load_file('config/health_check.yml')
    end

    attr_reader :ping_url

    def initialize(check_name)
      @ping_url = HEALTH_CHECK_CONFIG[check_name]
    end

    def ping_ok
      ping(ping_url) if ping_url.present?
    end

    def ping_start
      ping(ping_url.to_s + '/start') if ping_url.present?
    end

    def ping_fail
      ping(ping_url.to_s + '/fail') if ping_url.present?
    end

    private
    
    def ping url
      begin 
        HTTParty.get(url) if url.present?
      rescue Exception => e
        LoggingService::GeneralLogging.new.create(nil, 'Health Check', {result: "Failed to send request to url: #{url} at #{Time.now}", error: e.message})
      end
    end
  end
end
