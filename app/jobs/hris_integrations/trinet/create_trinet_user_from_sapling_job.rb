class HrisIntegrations::Trinet::CreateTrinetUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :add_employee_to_hr, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)
    if user.present?
      ::HrisIntegrationsService::Trinet::ManageSaplingProfileInTrinet.new(user).perform('create')
    end
  end
end