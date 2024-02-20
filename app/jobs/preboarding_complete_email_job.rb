class PreboardingCompleteEmailJob  < ApplicationJob
  queue_as :mailers

  def perform(user_id)
  	user = User.find_by(id: user_id)
  	return if user.nil?
  	puts "------------------- Sending Preboarding email to the User #{user.id}"
  	Interactions::Users::PreboardingCompleteEmail.new(user).perform
  	puts "-------------- Sent Preboarding complete email -----------------"
  end
end
