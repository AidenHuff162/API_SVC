module Interactions
  module Users
    class Reminder

      def can_send_email?(overdue_notification, wday)
        ((overdue_notification == 'daily' && (1..5).include?(wday)) ||
        (overdue_notification == 'mondays_wednesdays_and_fridays' && [1, 3, 5].include?(wday)) ||
        (overdue_notification == 'tuesdays_and_thursdays' && [2, 4].include?(wday)) ||
        (overdue_notification == 'weekly_on_mondays' && wday == 1))
      end
    end
  end
end
