class HrisIntegrations::Deputy::RehireDeputyUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_deputy_integration, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)

    if user.present? && user.deputy_id.present?
      ::HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy.new(user).perform('rehire_and_update')
    end
  end
end