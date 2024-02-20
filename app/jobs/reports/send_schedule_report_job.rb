module Reports
  class SendScheduleReportJob
  	include Sidekiq::Worker
    include Sidekiq::Status::Worker
    sidekiq_options :queue => :send_schedule_report, :retry => false
    
    def perform(report_id, report_sent_at)
      report = Report.find_by_id report_id
      return unless report.present?
      users = getRecipients(report)
      count = 0 
      if users.count > 0
        file = nil
        if ['workflow', 'survey'].include?(report.report_type)
          collection_ids = Reports::ReportFieldsAndUsersCollection.fetch_task_user_connection_collection(report.company_id, report, nil)&.results.pluck(:id).uniq
          count = collection_ids.length rescue 0
        elsif report.report_type == 'document'
          signatory_ids = Reports::ReportFieldsAndUsersCollection.fetch_paperwork_requests_collection(report.company_id, report, nil)&.results.pluck(:id).uniq
          upload_ids = Reports::ReportFieldsAndUsersCollection.fetch_upload_requests_collection(report.company_id, report, nil)&.results.pluck(:id).uniq
          personal_ids = Reports::ReportFieldsAndUsersCollection.fetch_personal_requests_collection(report.company_id, report, nil)&.results.pluck(:id).uniq
          count = signatory_ids.count + upload_ids.count + personal_ids.count rescue 0
          file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.new.perform(report.id, signatory_ids, upload_ids, personal_ids, users.first.id, false, @jid)
        else
          collection_ids = Reports::ReportFieldsAndUsersCollection.fetch_user_collection(report.company_id, report, nil)&.results.pluck(:id).uniq
          count = collection_ids.length rescue 0
        end
        total count
        
        if report.user?
          file ||= "Write#{report.report_type.camelize}ReportCSVJob".constantize.new.perform(report.id, collection_ids, users.first.id, false, nil, @jid)
        else
          file ||= "Write#{report.report_type.camelize}ReportCSVJob".constantize.new.perform(report.id, collection_ids, users.first.id, false, @jid)
        end
        
        excel = false
        if report.workflow? || report.time_off?
          file = file[:meta][:file]
          excel = true
        end

        name = report.name.tr('/', '_')
        if report.meta['recipient_type'] && report.meta['recipient_type'] == 'sftp'
          SftpService::SendFileToSftp.new(report.sftp, file, false, name, users.first).perform
        else
          users.each do |user|
            begin
              UserMailer.csv_report_email(user, report, name, file, excel).deliver_now!
            rescue Exception => e
              LoggingService::GeneralLogging.new.create(report.try(:company), 'Create Email - Schedule Report Job', {result: 'Failed to send email after extracting users', error: e.message, report_id: report.id })
            end
          end
        end
        report.update_column(:sent_at, report_sent_at)
        File.delete(file) if file.present?
      end

      at count, "completed" if !report.time_off?
    end

    def getRecipients(report)
      users = []
      begin
        if report.meta
          company = report.company
          users = if ['users', 'sftp'].include?(report.meta['recipient_type'])
                    if report.meta['recipient_type'] == 'users'
                      ids = report.meta['individuals'].map{|a| a['id']}
                      company.users.where(id: ids)
                    elsif report.meta['recipient_type'] == 'sftp'
                      [report.users]
                    end
                  elsif report.meta['permission_groups']
                    role_ids = report.meta['permission_groups']
                    role_ids = company.user_roles.pluck(:id).uniq if report.meta['permission_groups'].include?("all")
                    company.users.where(user_role_id: role_ids, state: 'active')
                  end
        end
      rescue Exception => e
        LoggingService::GeneralLogging.new.create(report.try(:company), 'Create Email - Schedule Report Job', { result: 'Failed to add recipients', error: e.message, report_id: report.id })
      end
      users.uniq
    end
  end
end
