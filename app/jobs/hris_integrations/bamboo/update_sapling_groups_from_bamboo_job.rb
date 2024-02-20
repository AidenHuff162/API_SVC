class HrisIntegrations::Bamboo::UpdateSaplingGroupsFromBambooJob < ApplicationJob
  queue_as :update_departments_and_locations

  def perform(company)
    ::HrisIntegrationsService::Bamboo::UpdateSaplingGroups.new(company).perform
  end
end
