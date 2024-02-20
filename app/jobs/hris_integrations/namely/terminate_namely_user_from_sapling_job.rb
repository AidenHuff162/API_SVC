class HrisIntegrations::Namely::TerminateNamelyUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :update_employee_to_hr, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)
    if user.present? && user.namely_id.present? && user.company.present?
      ::HrisIntegrationsService::Namely::ManageSaplingProfileInNamely.new(user.company, user).perform('terminate')
    end
  end
end