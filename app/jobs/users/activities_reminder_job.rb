module Users
  class ActivitiesReminderJob < ApplicationJob
    def perform
      Interactions::Users::ActivitiesReminder.new.perform
    end
  end
end
