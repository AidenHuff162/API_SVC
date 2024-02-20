class BswiftService::WriteCSV

  CSV_OPEN_MODE_HASH = {
    emersoncollective: 'w:bom|utf-8',
  }
  # Commented BOM as it starts appearing in excel and causes problems.
  # CSV_BOM = "\xEF\xBB\xBF"

  COLUMN_HEADERS = ['Group Number', 'UserID', 'Social Security Number','EmployeeID','Payroll ID', 'Relation',
                    'First Name', 'Middle Initial', 'Last Name', 'Employment Status', 'Benefit Class Code',
                    'Benefit Class Date', 'Hire Date', 'Re-hire Date', 'Termination Date', 'Termination Reason',
                    'Job Title', 'Time Status', 'Salary', 'Hourly Rate', 'Hours Per Week', 'Bonus',
                    'Bonus Effective Date', 'Commission', 'Commission Effective Date', 'Benefits Base Salary',
                    'Compensation Date', 'Pay Frequency', 'Department Code', 'Location Code', 'Division Code',
                    'Date of Birth', 'Gender', 'Home Address1', 'Home Address2', 'City', 'State', 'ZIP', 'Home Phone',
                    'Cell Phone', 'Work e-mail', 'Alternate e-mail', 'User Name', 'Auto-Enroll']

  def initialize(company, integration, employees)
    @company = company
    @integration = integration
    @employees = employees
  end

  def perform
    open_mode = CSV_OPEN_MODE_HASH[@company.subdomain.to_sym] || 'w+:UTF-16LE:UTF-8'
    written_user_ids , filename, num_rows = [], "tmp/#{@company.name}_#{Date.today.to_s}.csv", 0
    CSV.open(filename, open_mode, write_headers: true, headers: COLUMN_HEADERS) do |writer|
      # writer.to_io.write CSV_BOM
      
      @employees.each do |user|
        row_values = BswiftService::FetchRows.new(user, @integration, @company).perform
        if row_values != -1
          writer << row_values
          num_rows += 1
          written_user_ids.push(user.id)
        else
          next
        end
      end
    end
    return [filename, num_rows, written_user_ids]
  end
end
