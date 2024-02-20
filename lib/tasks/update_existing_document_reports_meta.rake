namespace :update_existing_document_reports_meta do
  task update_user_state_filter: :environment do
    puts 'Update Existing Document Reports Meta - Started'
    document_reports = Report.all.where(report_type: Report.report_types[:document])
    document_reports.try(:find_each) do |report|
      report.meta['user_state_filter'] = 'all_users'
      report.save
    end
    puts 'Update Existing Document Reports Meta - Finished'
  end
end
