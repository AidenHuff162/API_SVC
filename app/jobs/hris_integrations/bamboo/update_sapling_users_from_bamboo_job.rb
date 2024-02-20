class HrisIntegrations::Bamboo::UpdateSaplingUsersFromBambooJob < ApplicationJob
  queue_as :receive_employee_from_hr

  def perform(company_id, is_update_all = false)
    company = Company.find(company_id)
    begin
      ::HrisIntegrationsService::Bamboo::UpdateSaplingFromBamboo.new(company, is_update_all).perform
    rescue Bamboozled::AuthenticationFailed => e
      LoggingService::IntegrationLogging.new.create(company, 'BambooHR', 'Create user', {request: 'create_user'}, {result: 'Authentication failed: 401, API key is missing or invalid.'}, 401)
    end
  end
end
