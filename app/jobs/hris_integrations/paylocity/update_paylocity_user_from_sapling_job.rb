class HrisIntegrations::Paylocity::UpdatePaylocityUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :update_employee_to_hr, :retry => false, :backtrace => true

  def perform(user_id, attributes)
    user = User.find_by(id: user_id)

    if user.present? && user.paylocity_id.present? && attributes.present?
      ::HrisIntegrationsService::Paylocity::ManageSaplingProfileInPaylocity.new(user).perform('update', attributes)
    end
  end
end