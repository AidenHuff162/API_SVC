module Inbox
  class UpdateScheduledEmail

    def update_scheduled_user_emails user, original_user
      if user.start_date != original_user.start_date
       user.key_date_changed "start date"
       user.key_date_changed "anniversary"
      end
      if user.last_day_worked != original_user.last_day_worked
        user.key_date_changed "last day worked"
      end      
      if user.termination_date != original_user.termination_date
        user.key_date_changed "date of termination"
      end
      if user.date_of_birth != original_user.date_of_birth
        user.key_date_changed 'birthday'
      end
    end
  end
end