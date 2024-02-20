class DestroyPreStartEmailJob < ApplicationJob

  def perform(user_id)
    jobs = Sidekiq::ScheduledSet.new
    jobs.each do |email|
      if email.display_class == "UserMailer.pre_start_email"
        args = email.display_args
        userId = args[0].user_id if args
        if user_id == userId
          email.delete
        end
      end
    end
  end
end
