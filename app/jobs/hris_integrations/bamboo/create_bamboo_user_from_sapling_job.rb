class HrisIntegrations::Bamboo::CreateBambooUserFromSaplingJob < ApplicationJob
  queue_as :add_employee_to_hr

  def perform(user_id, is_send_documents = false)  	
    user = User.find_by_id(user_id)
    return if user.nil? || user.super_user
    ::HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(user, true).create(is_send_documents) if !user.bamboo_id.present?
  end
end
