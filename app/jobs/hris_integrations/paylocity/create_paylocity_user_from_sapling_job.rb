class HrisIntegrations::Paylocity::CreatePaylocityUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :add_employee_to_paylocity, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)
    if user.present?
      ::HrisIntegrationsService::Paylocity::ManageSaplingProfileInPaylocity.new(user).perform('create')
    end
  end
end