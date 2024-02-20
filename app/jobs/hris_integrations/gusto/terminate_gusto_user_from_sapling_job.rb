class HrisIntegrations::Gusto::TerminateGustoUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :update_employee_to_hr, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)

    if user.present? && user.gusto_id.present?
      ::HrisIntegrationsService::Gusto::ManageSaplingProfileInGusto.new(user).perform('terminate')
    end
  end
end