class WeeklyHiresEmailJob < ApplicationJob

  def perform
    now = Time.now.utc
    return unless [0,1,2].include?(now.wday)
    current_time_zones = get_time_zones
    alerts = CustomEmailAlert.joins(:company).where(custom_email_alerts: { alert_type: CustomEmailAlert.alert_types[:new_hires] }, companies: { time_zone: current_time_zones })
    alerts.each do |alert|
      WeeklyHiresEmailService.new(alert).perform if alert.is_enabled? && alert.company.account_state == "active"
    end
  end

  def get_time_zones
    current_time_zones = []
    ActiveSupport::TimeZone.all.select do |time_zone|
      current_time_zones.push(time_zone.name) if time_zone.now.hour == 6 && time_zone.now.min.between?(0, 59) && time_zone.today.monday?
    end
    current_time_zones
  end

end
