class LogoutUserOnPermissionUpdateJob
	include Sidekiq::Worker
  sidekiq_options :queue => :logout_user, :retry => false, :backtrace => true

  def perform(user_role_id)
  	return unless user_role_id.present?
		
	@users = UserRole.find_by(id: user_role_id).users
    @users.each { |user| user.logout_user }
  end
end