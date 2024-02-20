module Interactions
  module UserEmails
    #Start ScheduleCustomEmail
    class ScheduleCustomEmail
      attr_reader :user_email

      def initialize(user_email, is_termination_email = false, is_daylight_save=nil, is_resend_invite = false, flatfile_rehire = false)
        @user_email = user_email
        @is_daylight_save = is_daylight_save
        @is_termination_email = is_termination_email
        @is_resend_invite = is_resend_invite
        @flatfile_rehire = flatfile_rehire
      end

      def perform
        scheduled_wrt_company_time = user_email.time_wrt_company_timezone
        if user_email.schedule_options["time_zone"].present? && user_email.invite_at
          scheduled_wrt_company_time = user_email.invite_at.to_formatted_s(:db).in_time_zone(user_email.schedule_options["time_zone"]).to_time.utc
        end
        if user_email.schedule_options["send_email"] != 0 && user_email.invite_at && scheduled_wrt_company_time >= Time.now.utc
          if @is_termination_email
            job_id = UserMailer.delay_until(scheduled_wrt_company_time, queue: 'mailers').termination_email(@user_email.id)
          else
            job_id = UserMailer.delay_until(scheduled_wrt_company_time, queue: 'mailers').custom_email(@user_email.id, nil, nil, false, @is_resend_invite)
          end
          user_email.update_column(:job_id, job_id)
        else
          @user_email.update(invite_at: user_email.company_time)
          if @is_termination_email
            UserMailer.termination_email(user_email.id).deliver_later!
          elsif @flatfile_rehire
            UserMailer.custom_email(@user_email.id, nil, nil, false, @is_resend_invite).deliver_now!
          else
            UserMailer.custom_email(@user_email.id, nil, nil, false, @is_resend_invite).deliver_later!
          end

        end
      end

      def perform_test(current_user)
        UserMailer.custom_email(nil, @user_email, current_user).deliver_now!
      end
    end
    #END ScheduleCustomEmail
  end
end

