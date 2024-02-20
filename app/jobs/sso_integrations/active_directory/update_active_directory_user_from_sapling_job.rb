class SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_one_login_integration, :retry => false, :backtrace => true
  
  def perform(user_id, attributes)
    user = User.find_by_id(user_id)

    return unless user.present? && user.company.can_provision_adfs? && user.active_directory_object_id.present?
    ::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory.new(user).perform('update', attributes)
  end
end