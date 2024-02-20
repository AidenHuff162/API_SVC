module LoggingManagement
  extend ActiveSupport::Concern

  def create_general_logging(company, action, result, type='Overall')
    LoggingService::GeneralLogging.new.create(company, action, result, type)
  end

  def create_integration_log(company, integration, action, request, response, status)
    LoggingService::IntegrationLogging.new.create(company, integration, action, request, response, status)
  end
end
