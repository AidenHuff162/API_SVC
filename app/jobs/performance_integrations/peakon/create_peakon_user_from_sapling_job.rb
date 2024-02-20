class PerformanceIntegrations::Peakon::CreatePeakonUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_deputy_integration, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)

    if user.present? && user.peakon_id.blank?
      ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(user).perform('create')
    end
  end
end