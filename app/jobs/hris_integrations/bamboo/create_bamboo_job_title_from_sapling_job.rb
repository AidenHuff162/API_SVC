class HrisIntegrations::Bamboo::CreateBambooJobTitleFromSaplingJob < ApplicationJob
  queue_as :update_departments_and_locations

  def perform(company, title)
    ::HrisIntegrationsService::Bamboo::JobTitle.new(company).create(title)
  end
end
