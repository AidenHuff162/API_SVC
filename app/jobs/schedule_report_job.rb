class ScheduleReportJob
  include Sidekiq::Worker
  sidekiq_options :queue => :report_schedule, :retry => false

  def perform
    current_time_zones = Company.all.pluck(:time_zone).uniq
    current_time_zones.each do |time_zone|
      dt = roundTime(1.hour, time_zone)
      time_zone_reports = Report.joins(:company).where( companies: {time_zone: time_zone})
      today_reports = getAllCurrentDateReports(time_zone_reports, dt)
      this_hour_report_ids = getAllCurrentHourReports(today_reports, dt)
      reports = time_zone_reports.where(id: this_hour_report_ids.uniq)
      
      reports.each do |report|
        begin
          next if dt.strftime('%m/%d/%Y') == report&.sent_at&.strftime('%m/%d/%Y')
          queue_name = ScheduleReportService.call(report)
          jid = Reports::SendScheduleReportJob.set(queue: queue_name).perform_async(report.id, dt)
          report.update(job_id: jid, scheduled_at: dt)
        rescue Exception => e
          LoggingService::GeneralLogging.new.create(report.try(:company), 'Create Email - Schedule Report Job', {result: 'Failed to send email after extracting reports', error: e.message, report_id: report.id })           
        end
      end
    end
  end

  def roundTime(granularity=1.hour, time_zone)
    Time.use_zone(time_zone) do
      Time.zone.at((DateTime.now.to_time.to_i/granularity).round * granularity).to_datetime
    end
  end

  def getAllCurrentDateReports(reports, dt)
    current_day = dt.strftime("%As")
    current_date = dt.strftime("%d").to_i
    current_date = "End of Month" if (dt + 1).day == 1

    reports_array = []
    reports.find_each do |report|
      if report.meta['schedule_type'] == 'daily'
        reports_array.push report
      elsif report.meta['schedule_type'] == 'weekly' && report.meta['schedule_days'] == current_day
        reports_array.push report
      elsif report.meta['schedule_type'] == 'every_2_weeks' && report.meta['schedule_days'] == current_day
        reports_array.push report if validWeeklyDate(report, dt)
      elsif report.meta['schedule_type'] == 'twice_a_month' && (report.meta['schedule_days'] == current_date || report.meta['schedule_dates'] == current_date)
        reports_array.push report
      elsif report.meta['schedule_type'] == 'monthly' && report.meta['schedule_days'] == current_date
        reports_array.push report
      end
    end

    reports_array
  end

  def getAllCurrentHourReports(reports, dt)
    reports_array = []
    reports.find_all do |report|
      if report.meta['schedule_time'] == dt.strftime('%I:00 %P') && if_not_scheduled?(report, dt)
        reports_array.push report.id
      end
    end
    reports_array
  end

  def if_not_scheduled?(report, dt)
    dt.strftime('%m/%d/%Y') != report&.scheduled_at&.strftime('%m/%d/%Y') || ![:complete, :working, :queued].include?(Sidekiq::Status::status(report.job_id))
  end

  def validWeeklyDate(report, current_date)
    start_date = Date.strptime(report.meta['schedule_dates'][0], '%m/%d/%Y').try(:to_datetime)
    second_date = Date.strptime(report.meta['schedule_dates'][1], '%m/%d/%Y').try(:to_datetime)

    if current_date === start_date || current_date === second_date
      return true
    elsif current_date > second_date
      diff = (current_date.to_date - second_date.to_date).numerator
      return true if diff % 14 == 0
    else
      return false
    end         
  end

end
