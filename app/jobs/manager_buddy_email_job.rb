class ManagerBuddyEmailJob
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(user_id, is_manager = true, buddy_or_manager_id)
  	user = User.find_by(id: user_id)
    buddy_or_manager = User.find_by(id: buddy_or_manager_id)

    return if user.nil? || buddy_or_manager.nil?

    if is_manager && user.manager.present?
  		puts "------------------- Sending ManagerBuddyEmail to the User #{user.id} AS Manager"
  		Interactions::Users::ManagerBuddyEmail.new(user, buddy_or_manager, 'Manager', 'new_manager').perform
  		puts "-------------- Sent ManagerBuddyEmail -----------------"

    elsif user.buddy.present? || buddy_or_manager.present?
  		puts "------------------- Sending ManagerBuddyEmail to the User #{user.id} AS buddy"
  		Interactions::Users::ManagerBuddyEmail.new(user, buddy_or_manager, user.company.buddy, 'new_buddy').perform
  		puts "-------------- Sent BuddyEmail -----------------"
  	end
  end
end
