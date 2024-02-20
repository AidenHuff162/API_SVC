class PerformanceIntegrations::FifteenFive::CreateFifteenFiveUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_deputy_integration, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)

    if user.present? && user.fifteen_five_id.blank?
      ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(user).perform('create')
    end
  end
end