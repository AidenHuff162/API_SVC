require 'csv'
require 'reports/report_fields_and_users_collection'
require 'rubygems'
require 'write_xlsx'
require 'roo'
class WriteWorkflowReportCSVJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  sidekiq_options :queue => :generate_big_reports, :retry => false, :backtrace => true
  attr_accessor :report, :task_user_connections, :user, :send_email

  if Rails.env.development? || Rails.env.test?
      FILE_STORAGE_PATH = ("#{Rails.root}/tmp")
  else
      FILE_STORAGE_PATH = File.join(Dir.home, 'www/sapling/shared/')
  end
  
  def perform(report_id, task_user_connections_ids, user_id, send_email=false, jid=nil)
    @jid ||= jid
    @report = Report.find_by(id: report_id)
    @user = @report.company.users.find_by(id: user_id)
    @send_email = send_email

    sort_params = ReportService.new().get_sorting_params(@report)
    @task_user_connections = []

    if sort_params[:order_column] == 'due_date'
      @task_user_connections = TaskUserConnection.with_deleted.where(id: task_user_connections_ids).order("task_user_connections.due_date #{sort_params[:order_in]}")
    end
    name = @report.name.tr('/' , '_')
    titleize_permanent_fields = ["Task Name", "Task ID", "Task Description", "Task Timing", "Task Timeline", "Workflow", "Workflow ID", "Task Owner ID", "Task Owner Name", "Task Receiver ID", "Task Receiver Name", "Workspace ID", "Workspace Name", "State", "Due Date", "Created At", "Updated At"]
    write_workflow_excel_sheet(name, titleize_permanent_fields)
  end

  private

  def write_workflow_excel_sheet(name, titleize_permanent_fields)
    file = File.join(FILE_STORAGE_PATH,"#{name}#{rand(1000)}.xlsx")
    workbook = WriteXLSX.new(file)
    format = workbook.add_format
    format.set_text_wrap
    worksheet = workbook.add_worksheet('Workflows')
    worksheet2 = workbook.add_worksheet('Comments')
    worksheet3 = workbook.add_worksheet('Subtasks')
    worksheet.set_column(0, 2, 20)
    worksheet.set_column(3, 3, 40)
    worksheet.set_column(4, 15, 20)
    worksheet2.set_column(0, 15, 20)
    worksheet3.set_column(0, 15, 20)
    reset_row_and_column
    titleize_permanent_fields.each do |title|
      worksheet.write(@row, @column, title)
      increment_column
    end
    reset_column
    Reports::ReportFieldsAndUsersCollection.workflow_tasks_comments_headers.each do |title|
      worksheet2.write(@row, @column, title)
      increment_column
    end
    reset_column
    Reports::ReportFieldsAndUsersCollection.workflow_tasks_subtasks_headers.each do |title|
      worksheet3.write(@row, @column, title)
      increment_column
    end

    increment_row
    reset_column
    row_sheet_2 = 1
    row_sheet_3 = 1
    total task_user_connections.length
    task_user_connections.each_with_index do |record, index|
      at index + 1, "#{name} - #{index}" if index%10 == 0
      user.get_workflow_fields_values(record).each do |v|
        begin
          value = v.to_s
          value = "#{value}" if value.present? && value.match(/[-+=@|]/).present? 
          worksheet.write(@row, @column, value, format)
          increment_column
        rescue
          next
        end
      end
      record.comments.with_deleted.each do |comment|
        comm = user.get_workflow_tasks_comments(comment, record)
        worksheet2.write_row(row_sheet_2, 0, comm)
        row_sheet_2 += 1
      end
      record.task.sub_tasks.with_deleted.each do |sub_task|
        subtask = user.get_workflow_sub_tasks(sub_task, record.id)
        worksheet3.write_row(row_sheet_3, 0, subtask)
        row_sheet_3 += 1
      end
      increment_row
      reset_column
    end
    workbook.close
    xlsx = Roo::Spreadsheet.open(file, extension: :xlsx)

    if send_email
      UserMailer.csv_report_email(user, report, name, file, true).deliver_now!
      File.delete(file) if file.present?
      at task_user_connections.length, "completed"
    else
      {workflows: xlsx.sheet(0).parse(headers: true), comments: xlsx.sheet(1).parse(headers: true), subtasks: xlsx.sheet(2).parse(headers: true), meta: {report_name: report.name, file: file}}
    end
  end

  def reset_row_and_column
    reset_row
    reset_column
  end

  def increment_row
    @row += 1
  end

  def increment_column
    @column += 1
  end

  def reset_row
    @row = 0
  end

  def reset_column
    @column = 0
  end
end
