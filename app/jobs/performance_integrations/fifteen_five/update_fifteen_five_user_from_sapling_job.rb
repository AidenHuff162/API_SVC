class PerformanceIntegrations::FifteenFive::UpdateFifteenFiveUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_deputy_integration, :retry => false, :backtrace => true

  def perform(args)
    user = User.find_by(id: args['user_id'])

    if user.present? && user.fifteen_five_id.present?
      ::PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive.new(user).perform('update')
    end
  end
end