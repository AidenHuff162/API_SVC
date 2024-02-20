class HrisIntegrations::Namely::CreateNamelyUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :add_employee_to_hr, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)
    if user.present? && user.namely_id.blank?
      ::HrisIntegrationsService::Namely::ManageSaplingProfileInNamely.new(user.company, user).perform('create')
    end
  end
end