class CustomEmailAlert < ApplicationRecord
  has_paper_trail
  acts_as_paranoid

  belongs_to :company
  belongs_to :edited_by, class_name: 'User'

  enum alert_type: { timeoff_approved: 0, timeoff_requested: 1, timeoff_denied: 2, timeoff_canceled: 3, termination: 4, new_hires: 5, negative_balance: 6, weekly_metrics: 7}
  enum notified_to: { permission_group: 0, individual: 1 }

  def self.sent_custom_alert_test_email(custom_email_alert, user)
    if custom_email_alert.alert_type == 'termination'
      sent_terminated_alert_email(custom_email_alert, user)
    elsif custom_email_alert.alert_type == 'new_hires'
      WeeklyHiresEmailService.new(custom_email_alert).test(user)
    elsif custom_email_alert.alert_type == 'negative_balance'
      send_negative_balance_alert(custom_email_alert, user)
    elsif custom_email_alert.alert_type == 'weekly_metrics'
      ::RoiEmailManagementServices::WeeklyMetricsEmail.new(custom_email_alert).test(user)
    else
      sent_time_off_alert_email(custom_email_alert, user)
    end
  end

  def self.sent_time_off_alert_email(custom_email_alert, user)
    pto_request_params = {begin_date: Time.now, end_date: Time.now, user_id: user.id, partial_day_included: false,
      balance_hours: 16, pto_policy: PtoPolicy.new({name: 'Dummy Policy', policy_type: 'vacation', tracking_unit: 'hourly_policy'})}
    TimeOffMailer.time_off_custom_alert(custom_email_alert, user, PtoRequest.new(pto_request_params)).deliver_now!
  end

  def self.sent_terminated_alert_email(custom_email_alert, user)
    user_params = {id: user.id, company_id: user.company_id, first_name: 'Dummy', preferred_name: 'Dummy', last_name: 'Name', state: 'active', current_stage: 'pre_start',
      email: 'dummy@test.com', personal_email: 'dummy+1@personal.com', termination_date: Date.today, last_day_worked: Date.today}
    UserMailer.terminated_custom_alert(user, user, User.new(user_params), custom_email_alert).deliver_now!
  end

  def self.send_negative_balance_alert(custom_email_alert, user)
    TimeOffMailer.send_negative_balance_alert(custom_email_alert, user).deliver_now!
  end
end
