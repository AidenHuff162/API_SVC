class PerformanceIntegrations::Peakon::UpdatePeakonUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_deputy_integration, :retry => false, :backtrace => true

  def perform(args)
    user = User.find_by(id: args['user_id'])
    if user.present? && user.peakon_id.present?
      ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(user).perform('update', args['attribute'])
    end
  end
end