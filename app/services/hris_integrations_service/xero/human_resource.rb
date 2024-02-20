class HrisIntegrationsService::Xero::HumanResource
  attr_reader :company, :access_token, :xero

  delegate :fetch_integration, :refresh_token, :create_loggings, to: :helper_service

  def initialize(company, instance_id=nil, user_id=nil)
    @user = company.users.find_by(id: user_id)
    @company = company
    @xero = fetch_integration(company, @user, instance_id)
    @access_token = authenticate_access_token
  end

  def create_leave_types(data)
    response = post("/payroll.xro/1.0/Payitems", data)
    @xero.update_column(:synced_at, DateTime.now) if @xero
    ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    return response
  end

  def fetch_leave_types
    response = nil

    begin
      response = get("/payroll.xro/1.0/Payitems")["PayItems"]["LeaveTypes"]
      @xero.update_column(:synced_at, DateTime.now) if @xero
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(401, 'Fetching Leave Types - ERROR', { message: e.message })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      return [{error: e.message}]
    end

    return response
  end

  def create_leave_applications(data)
    response = post("/payroll.xro/1.0/Leaveapplications", data)
    @xero.update_column(:synced_at, DateTime.now) if @xero
    ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    return response
  end

  def post_request(data)
    response = post("/payroll.xro/1.0/Employees", data)
    @xero.update_column(:synced_at, DateTime.now) if @xero
    ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    return response
  end

   def fetch_payroll_calendars
    response = nil
    begin
      response = get("/payroll.xro/1.0/PayrollCalendars")["PayrollCalendars"]
      @xero.update_column(:synced_at, DateTime.now) if @xero
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(401, 'Fetching Payroll Calendars - ERROR', { message: e.message })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      return [{error: e.message}]
    end

    return response
  end

  def fetch_organisations
    response = nil

    begin
      response = get("/api.xro/2.0/Organisations")["Organisations"]
      @xero.update_column(:synced_at, DateTime.now) if @xero
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(401, 'Fetching Organisations - ERROR', { message: e.message })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      return [{error: e.message}]
    end

    return response
  end

  def fetch_employee_groups
    response = nil

    begin
      response = get("/api.xro/2.0/TrackingCategories")["TrackingCategories"]
      @xero.update_column(:synced_at, DateTime.now) if @xero
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(401, 'Fetching Employee Groups - ERROR', { message: e.message })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      return [{error: e.message}]
    end

    return response
  end

  def fetch_pay_templates
    response = nil

    begin
      response = get("/payroll.xro/1.0/PayItems")["PayItems"]["EarningsRates"].select{|e| e["RateType"]=="RATEPERUNIT"}
      @xero.update_column(:synced_at, DateTime.now) if @xero
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(401, 'Fetching Pay Templates - ERROR', { message: e.message })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      return [{error: e.message}]
    end

    return response
  end

  def fetch_user data
    response = nil

    response = get("/payroll.xro/1.0/Employees/#{data.xero_id}")
    @xero.update_column(:synced_at, DateTime.now) if @xero
    ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    return response
  end

  def fetch_users(page_no)
    response = nil

    response = get("/payroll.xro/1.0/Employees?page=#{page_no}")
    @xero.update_column(:synced_at, DateTime.now) if @xero
    ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    return response
  end

  def fetch_payroll_calendar
    response = nil
    response = get("/payroll.xro/1.0/PayrollCalendars/#{@xero.payroll_calendar}")["PayrollCalendars"]
    @xero.update_column(:synced_at, DateTime.now) if @xero
    ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    return response
  end


  private
 # :nocov:
  def authenticate_access_token
    refresh_token @xero
  end
 # :nocov:
  def post(url, data)
    HTTParty.post('https://api.xero.com'+url,
      body:data,
      headers: { 'Content-Type' => 'Application/xml', 'Accept' => 'application/json', 'Xero-tenant-id' => xero.company_code, 'Authorization' => 'Bearer ' + xero.reload.access_token.to_s }
    ) 
  end

  def get(url)
    response = HTTParty.get('https://api.xero.com'+url,
      headers: {'Accept' => 'application/json', 'Xero-tenant-id' => xero.company_code, 'Authorization' => 'Bearer ' + xero.reload.access_token.to_s}
    )

    raise 'Unauthorized' if response.present? && response.code == 401
    raise 'Forbidden' if response.present? && response.code == 403
    raise 'Not Found' if response.present? && response.code == 404
    response = JSON.parse(response.body)
    return response
  end

  def helper_service
    HrisIntegrationsService::Xero::Helper.new
  end

  def log(status, action, result, request = nil)
    if result[:message] == 'Unauthorized'
      status = 401  
    elsif result[:message] == 'Forbidden'
      status = 403  
    elsif result[:message] == 'Not Found'
      status = 404  
    else 
      status = 500  
    end

    create_loggings(company, "Xero", status, action, result, request)
  end
end
