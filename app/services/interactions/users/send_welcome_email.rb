module Interactions
  module Users
    class SendWelcomeEmail
      attr_reader :current_time_zones

      def perform
        current_time_zones = Company.all.pluck(:time_zone).uniq
        relation = UserEmail.joins(user: :company).where(job_id: nil).where(email_type: 'welcome_email').where.not("schedule_options -> 'send_email' @> ?", UserEmail::send_emails[:immediatly])
        current_time_zones.each do |time_zone|
          dt = roundTime(30.minutes, time_zone)
          emails = relation.where(companies: {time_zone: time_zone}).where(email_status: [UserEmail.statuses[:scheduled], UserEmail.statuses[:rescheduled]]).where("DATE(invite_at) = ?", dt.to_date).where("invite_at::time = ?", dt.to_s(:time))
          emails.each do |email|
            UserMailer.pre_start_email(email.id).deliver_later!
          end
        end
      end

      def roundTime(granularity=1.hour, time_zone)
        Time.use_zone(time_zone) do
          Time.zone.at((DateTime.now.to_time.to_i/granularity).round * granularity).to_datetime
        end
      end
    end
  end
end
