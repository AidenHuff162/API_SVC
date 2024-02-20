class SsoIntegrations::Gsuite::ReactivateGsuiteProfile
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_one_login_integration, :retry => false, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)

    return unless user.present?
    
    ::Gsuite::ManageAccount.new.reactivate_gsuite_account(user)
  end
end
