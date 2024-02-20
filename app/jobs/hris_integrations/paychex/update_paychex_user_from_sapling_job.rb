class HrisIntegrations::Paychex::UpdatePaychexUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :update_employee_to_hr, :retry => false, :backtrace => true

  def perform(user_id, attributes)
    user = User.find_by(id: user_id)
    
    if user.present? && user.paychex_id.present?
      ::HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex.new(user).perform('update', attributes)
    end
  end
end