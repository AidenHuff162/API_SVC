require 'csv'
require 'reports/report_fields_and_users_collection'

class WriteTrackUserChangeReportCSVJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  sidekiq_options :queue => :generate_big_reports, :retry => false, :backtrace => true
  attr_accessor :start_date, :end_date

  if Rails.env.development? || Rails.env.test?
      FILE_STORAGE_PATH = ("#{Rails.root}/tmp")
  else
      FILE_STORAGE_PATH = File.join(Dir.home, 'www/sapling/shared/')
  end
  
  def perform(report_id, ids, user_id, send_email=false, jid=nil)
    @jid ||= jid
    report = Report.find_by(id: report_id)
    @start_date = Date.strptime(report.meta['start_date'],'%m/%d/%Y') rescue nil
    @end_date = Date.strptime(report.meta['end_date'],'%m/%d/%Y') rescue nil
    company_users = report.company.users.where(id: ids)
    name = report.name.tr('/' , '_')
    file = File.join(FILE_STORAGE_PATH,"#{name}#{rand(1000)}.csv")
    report_permanent_fields = report.permanent_fields.pluck('id')
    headers = [ 'Timestamp', 'Changed by Name', 'Changed by UserID', 'GUID', fetch_permanent_fields(report_permanent_fields),
                'Section/Table', 'Field ID', 'Field Name', 'Field Type', 'Old Value', 'New Value' ].flatten

    reporting_fields, custom_fields, permanent_fields = Reports::ReportFieldsAndUsersCollection.get_fields_for_user_track_change_report(report)
    total ids.length
    CSV.open(file, 'w:bom|utf-8', write_headers: true, headers: headers) do |writer|
      company_users.find_each(batch_size: 100).with_index do |report_user, index|
        begin
          at index, "#{name} - #{index}" if index%10 == 0
          field_histories = fetch_user_histories(report_user)
          reporting_fields.each do |reporting_field|
            reporting_profile_field = fetch_reporting_profile_field(permanent_fields, custom_fields, reporting_field['id'])
            if reporting_profile_field
              profile_field_history = fetch_field_history(reporting_profile_field, field_histories)
              if profile_field_history.count > 0
                report_user.get_tracked_field_values(reporting_profile_field, profile_field_history, report_permanent_fields).each do |row|
                  writer << row
                end
              end
            end
          end
        rescue
          next
        end
      end
    end

    if send_email
      user = report.company.users.find_by(id: user_id)
      UserMailer.csv_report_email(user, report, name, file).deliver_now!
      File.delete(file) if file.present?
      at ids.length, "completed"
    else
      file
    end
  end

  private

  def fetch_reporting_profile_field(permanent_fields, custom_fields, reporting_field_id)
    permanent_fields.detect { |permanent_field| permanent_field['id'] == reporting_field_id } || custom_fields.find_by(id: reporting_field_id)
  end

  def fetch_field_history(reporting_profile_field, field_histories)
    if reporting_profile_field['isDefault'] != nil

      case reporting_profile_field['name']
      when 'Department'
        field_name = 'Team'
      when 'About'
        field_name = 'About You'
      when 'Job Title'
        field_name = 'Title'
      else
        field_name = reporting_profile_field['name']
      end

      return field_histories.where(field_name: field_name, custom_field_id: nil)
    else
      return field_histories.where(custom_field_id: reporting_profile_field['id'])
    end
  end

  def fetch_user_histories(user)
    if user.profile
      if @start_date && @end_date
        FieldHistory.where("(field_auditable_type = 'User' AND field_auditable_id = ?) OR (field_auditable_type = 'Profile' AND field_auditable_id = ?)", user.id, user.profile.id).where("created_at >= ? AND created_at <= ?", @start_date.beginning_of_day, @end_date.end_of_day)
      else
        FieldHistory.where("(field_auditable_type = 'User' AND field_auditable_id = ?) OR (field_auditable_type = 'Profile' AND field_auditable_id = ?)", user.id, user.profile.id)
      end
    else
      user.field_histories
    end
  end

  def fetch_permanent_fields(permanent_fields)
    header_fields = []
    default_fields = ActiveSupport::HashWithIndifferentAccess.new({
                                                                    ui: 'UserID',
                                                                    fn: 'First Name',
                                                                    ln: 'Last Name',
                                                                    ce: 'Company Email'})
    default_field_keys = default_fields.keys
    permanent_fields.try(:each) do |field|
      header_fields << default_fields[field] if default_field_keys.include?(field)
    end

    header_fields
  end
end
