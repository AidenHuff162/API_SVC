require 'csv'
require 'reports/report_fields_and_users_collection'
require 'rubygems'
require 'write_xlsx'
require 'roo'
class WriteTimeOffReportCSVJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  sidekiq_options :queue => :generate_big_reports, :retry => false, :backtrace => true

  if Rails.env.development? || Rails.env.test?
      FILE_STORAGE_PATH = ("#{Rails.root}/tmp")
  else
      FILE_STORAGE_PATH = File.join(Dir.home, 'www/sapling/shared/')
  end

  attr_accessor :report, :ids, :user, :pto_policies, :assigned_pto_policy_ids, :send_email, :policy_name, :displaying_unit

  def perform(report_id, ids, user_id, send_email=false, jid=nil)
    @jid ||= jid
    @report = Report.find_by(id: report_id)
    @user = @report.company.users.find_by(id: user_id)
    @ids = ids
    @send_email = send_email
    
    if report.meta["pto_policy"] == "all_pto_policies"
      @pto_policies = PtoPolicy.where(company_id: report.company_id)
      @policy_name = report.meta["pto_policy"]
    elsif report.meta["pto_policy"].kind_of?(Array) && report.meta["pto_policy"].count > 1
      @pto_policies = PtoPolicy.where(id: report.meta["pto_policy"], company_id: report.company_id)
      @policy_name = "Multiple Policies"
    else
      @pto_policies = PtoPolicy.where(id: report.meta["pto_policy"], company_id: report.company_id)
      @policy_name = pto_policies.first.name
    end
    @displaying_unit = fetch_displaying_unit
    name = report.name.tr('/' , '_')
    column_headers, fields_id = Reports::ReportFieldsAndUsersCollection.new.get_sreadsheet_fileds_and_custom_fields_reports(report)
    titleize_permanent_fields = column_headers.map { |h| h.present? ? h.titleize.tr("\n", " ")  : ''}
    write_excel_sheet(column_headers, fields_id, name, titleize_permanent_fields)
  end

  private

  def fetch_displaying_unit
    displaying_unit = @pto_policies.map {|a| a.displaying_unit}.uniq
    displaying_unit.count > 1 ? "Hours/Days" : displaying_unit[0]
  end

  def write_excel_sheet(column_headers, fields_id, name, titleize_permanent_fields)
    file = File.join(FILE_STORAGE_PATH,"#{name}#{rand(1000)}.xlsx")
    workbook = WriteXLSX.new(file)
    format = workbook.add_format
    format.set_text_wrap
    worksheet = workbook.add_worksheet('Balances')
    worksheet2 = workbook.add_worksheet('Requests')
    worksheet.set_column(0, 2, 20)
    worksheet.set_column(3, 3, 40)
    worksheet.set_column(4, 15, 20)
    worksheet2.set_column(0, 15, 20)
    worksheet.write(0, 0, 'Report Name')
    worksheet.write(0, 1, report.name)
    worksheet.write(1, 0, 'Policy Name')
    worksheet.write(1, 1, policy_name)
    worksheet.write(2, 0, 'Displaying in')
    worksheet.write(2, 1, displaying_unit)
    worksheet.write(3, 0, 'Begin Date')
    worksheet.write(3, 1, get_date(report.meta['start_date'], report))
    worksheet.write(4, 0, 'End Date')
    worksheet.write(4, 1, get_date(report.meta['end_date'], report))

    r = 6
    c = 0

    titleize_permanent_fields.each do |title|
      worksheet.write(r, c, title)
      c += 1
    end
    r += 1
    c = 0
    total_count = pto_policies.length * 2
    total total_count
    index = 0
    pto_policies.each do |pto_policy|
      index = index + 1
      at index, "#{name} - #{index}"
      report.company.users.where(id: ids).find_each(batch_size: 100)do |user|
        if user.assigned_pto_policies.find_by(pto_policy_id: pto_policy.id)
          user.get_timeoff_fields_values(column_headers, fields_id, report, report.meta, pto_policy, pto_policy.assigned_pto_policy_ids).each do |v|
            value = v.to_s
            if value.present?
              if (value[0] == '0' && !value.include?("/")) || value[0] == '+'
                value = "'#{value}'"
              else
                value = "#{value}"
              end
            end
            worksheet.write(r, c, value, format)
            c +=1
          end
          r += 1
          c = 0
        end
      end
    end
    r = 0
    c = 0
    Reports::ReportFieldsAndUsersCollection.bulk_time_off_headers.each do |title|
      worksheet2.write(r, c, title)
      c += 1
    end
    r += 1
    c = 0
    pto_policies.each do |pto_policy|
      index = index + 1
      at index, "#{name} - #{index}"
      report.company.users.where(id: ids).find_each(batch_size: 100)do |user|
        buffer = user.get_bulk_timeoff_fields_values(report, report.meta, pto_policy)
        worksheet2.write_col(r, 0, buffer)
        r += buffer.count
      end
    end
    workbook.close
    xlsx = Roo::Spreadsheet.open(file, extension: :xlsx)
    
    at total_count, "completed"
    if send_email
      UserMailer.csv_report_email(user, report, name, file, true).deliver_now!
      File.delete(file) if file.present?
    else
      return {requests: xlsx.sheet(1).parse(headers: true), balances: xlsx.sheet(0).parse(headers: true, header_search: [titleize_permanent_fields.first.to_s]), meta: {file: file, report_name: report.name, policy: policy_name, policy_unit: displaying_unit, begin_date: get_date(report.meta['start_date'], report), end_date: get_date(report.meta['end_date'], report)}}
    end
  end

  def get_date(date, report)
    date ? TimeConversionService.new(report.company).perform(Date.strptime(date, '%m/%d/%Y')) : 'All Available Dates'
  end

end
