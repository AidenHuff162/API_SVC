module Inbox
  class SetInviteAt

    def set_invite_at user_email
      if user_email["schedule_options"].present? && user_email["schedule_options"]["send_email"] == 1 #custome scheduled date
        date = Time.zone.parse(user_email["schedule_options"]["date"].to_s)
        date = date + Time.zone.parse(user_email["schedule_options"]["time"]).seconds_since_midnight.seconds if date && user_email["schedule_options"]["time"].present?
        user_email.invite_at = date
      elsif user_email["schedule_options"].present? && user_email["schedule_options"]["send_email"] == 2 #relative to key date
        # There are four keys here start date, Termination Date and annivers ary date, birthday
        date = get_key_date(user_email)
        if date && user_email["schedule_options"]["time"].present?
          date = date + Time.zone.parse(user_email["schedule_options"]["time"]).seconds_since_midnight.seconds
        end
        user_email.invite_at = date
      elsif user_email["schedule_options"].present? && user_email["schedule_options"]["send_email"] == 0
        user_email.invite_at = nil
      end
    end

    def get_key_date user_email
      user = user_email.user.reload
      if  ['start date', 'last day worked', 'date of termination'].include?(user_email["schedule_options"]["relative_key"])
        if user_email["schedule_options"]["relative_key"] == 'start date'
          date = user.start_date
        elsif user_email["schedule_options"]["relative_key"] == 'last day worked'
          date = user.last_day_worked || user_email["schedule_options"]['last_day_worked'].try(:to_date)
        elsif user_email["schedule_options"]["relative_key"] == 'date of termination'
          date = user.termination_date || user_email["schedule_options"]['termination_date'].try(:to_date)
        end
        if date && user_email["schedule_options"]["due"] == 'on'
          return date
        elsif date && user_email["schedule_options"]["due"] == 'before'
          # date - 3.days or 3.weeks etc
          return (date - eval(user_email["schedule_options"]["duration"].to_s + '.' + user_email["schedule_options"]["duration_type"]) )
        elsif date && user_email["schedule_options"]["due"] == 'after'
          return (date + eval(user_email["schedule_options"]["duration"].to_s + '.' + user_email["schedule_options"]["duration_type"]) )
        end
      elsif user_email["schedule_options"]["relative_key"] == 'birthday'
        return user.get_date_wrt_birthday(user_email["schedule_options"]["due"], user_email["schedule_options"]["duration"].to_s, user_email["schedule_options"]["duration_type"])
      elsif user_email["schedule_options"]["relative_key"] == 'anniversary'
        return user.get_date_wrt_anniversary(user_email["schedule_options"]["due"], user_email["schedule_options"]["duration"].to_s, user_email["schedule_options"]["duration_type"])
      end
    end
  end
end
