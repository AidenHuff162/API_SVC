class PerformanceIntegrations::Peakon::DeletePeakonUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_deputy_integration, :retry => false, :backtrace => true

  def perform(user)
    if user.present? && user.peakon_id.present?
      ::PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon.new(user).perform('delete')
    end
  end
end