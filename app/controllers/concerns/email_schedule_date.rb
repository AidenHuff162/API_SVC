module EmailScheduleDate
  extend ActiveSupport::Concern

  def update_email_schedule_date value_text
    date_of_birth = value_text.to_datetime rescue nil
    if date_of_birth.present?
      user_emails = self.user_emails.where("schedule_options ->> 'relative_key' = ?", "birthday")
      user_emails.try(:each) do |user_email|
        new_date = user_email.invite_at
        schedule_date = DateTime.new Date.today.year, date_of_birth.month, date_of_birth.day, new_date.hour, new_date.min, new_date.sec

        if schedule_date < Date.today
          schedule_date = schedule_date + 1.year
        end

        if user_email.schedule_options['due'] == 'before'
          schedule_date = (schedule_date - eval(user_email.schedule_options["duration"].to_s + '.' + user_email.schedule_options["duration_type"]) )
        elsif user_email.schedule_options['due'] == 'after'
          schedule_date = (schedule_date + eval(user_email.schedule_options["duration"].to_s + '.' + user_email.schedule_options["duration_type"]) )
        end

        user_email.invite_at = schedule_date
        user_email.save!
      end
    end
  end
end
