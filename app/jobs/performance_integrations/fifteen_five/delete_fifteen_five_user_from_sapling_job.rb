class PerformanceIntegrations::FifteenFive::DeleteFifteenFiveUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_deputy_integration, :retry => false, :backtrace => true

  def perform(user)
    if user.present? && user.fifteen_five_id.present?
      ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(user).perform('delete')
    end
  end
end