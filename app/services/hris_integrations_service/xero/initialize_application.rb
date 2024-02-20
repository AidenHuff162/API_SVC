class HrisIntegrationsService::Xero::InitializeApplication
  require 'openssl'
  delegate :create_loggings, :fetch_integration, to: :helper_service

  attr_reader :payload, :client, :company

  def initialize(company, payload, instance_id, current_user_id=nil)
    @company = company
    @payload = payload
    @xero = fetch_integration(company, nil, instance_id) 
    @user_id = current_user_id
  end

  def authorize_app_url
    state = JsonWebToken.encode({company_id: @company.id, instance_id: @xero&.id, user_id: @user_id, subdomain: @company.subdomain})
    "https://login.xero.com/identity/connect/authorize?response_type=code&client_id=#{ENV['XERO_CLIENT_ID']}&redirect_uri=#{REDIRECT_URL}&scope=offline_access payroll.employees payroll.settings accounting.settings&state=#{state}"
  end

  def prepare_authetication_url
    {url: authorize_app_url}
  end

  def save_access_token 
    begin
      @hr_service = HrisIntegrationsService::Xero::HumanResource.new(@company, @xero.id) 
      response = HTTParty.post("https://identity.xero.com/connect/token",
        body: "grant_type=authorization_code&code=#{payload['code']}&redirect_uri=#{REDIRECT_URL}",
        headers: { content_type: 'application/x-www-form-urlencoded', authorization: 'Basic ' + Base64.strict_encode64(ENV['XERO_CLIENT_ID'] + ':' + ENV['XERO_CLIENT_SECRET']) }
      )
      if response.ok?
        body = JSON.parse(response.body)
        update_refresh_and_access_token(body)
        get_xero_tenant_id
        create_leave_types_in_xero
        set_xero_dropdown_options
        log(response.code, 'Access Token Generation - Success', { params: payload.to_s, response: response.to_s})
        true
      else
        log(response.code, 'Access Token Generation - Failure', { params: payload.to_s, response: response.to_s})
        false
      end
    rescue Exception => e
      log(500, 'Access Token Generation - Failure', { params: payload.to_s, response: e.message})
      false
    end
  end

  private

  def set_xero_dropdown_options
    payroll_calendars = @hr_service.fetch_payroll_calendars
    employee_groups = @hr_service.fetch_employee_groups
    pay_templates = @hr_service.fetch_pay_templates

    payroll_calendar_configuration = @xero.integration_inventory.integration_configurations.find_by(field_name: 'Payroll Calendar')
    employee_group_configuration = @xero.integration_inventory.integration_configurations.find_by(field_name: 'Employee Group')
    pay_template_configuration = @xero.integration_inventory.integration_configurations.find_by(field_name: 'Pay Template')

    payroll_calendar = @xero.integration_credentials.find_or_create_by(name: payroll_calendar_configuration.field_name, integration_configuration_id: payroll_calendar_configuration.id)
    employee_group = @xero.integration_credentials.find_or_create_by(name: employee_group_configuration.field_name, integration_configuration_id: employee_group_configuration.id)
    pay_template = @xero.integration_credentials.find_or_create_by(name: pay_template_configuration.field_name, integration_configuration_id: pay_template_configuration.id)

    data = []
    payroll_calendars.each do |response_calendar|
      data.push({label: response_calendar['Name'], value: response_calendar['PayrollCalendarID']})
    end      
    payroll_calendar_configuration.update(dropdown_options: data)
    payroll_calendar.update(dropdown_options: data)

    data = []
    employee_groups.each do |response_group|
      response_group['Options'].each do |options|
        data.push({label: options['Name'], value: options['TrackingOptionID']})
      end
    end      
    employee_group_configuration.update(dropdown_options: data)
    employee_group.update(dropdown_options: data)

    data = []
    pay_templates.each do |response_template|
      data.push({label: response_template['Name'], value: response_template['EarningsRateID']})
    end      
    pay_template_configuration.update(dropdown_options: data)
    pay_template.update(dropdown_options: data)
  end

  def log(status, action, result, request = nil)
    create_loggings(company, 'Xero', status, action, result, request)
  end

  def helper_service
    HrisIntegrationsService::Xero::Helper.new
  end

  def create_leave_types_in_xero
    ::HrisIntegrations::Xero::CreateCompanyLeaveTypesInXero.perform_async(@company.id)
  end

  def update_refresh_and_access_token(body)
    @xero.access_token(body['access_token'])
    @xero.refresh_token(body['refresh_token'])
    @xero.expires_in(@xero.company.time)
    @xero.attributes = {is_authorized: true, connected_at: Time.now}
    @xero.connected_by_id = @user_id if @user_id.present?
    @xero.save!
  end

  def get_xero_tenant_id 
    response = HTTParty.get("https://api.xero.com/connections",
      headers: { content_type: 'application/x-www-form-urlencoded', authorization: 'Bearer ' + @xero.reload.access_token }
    )
    body = JSON.parse(response.body)
    @xero.company_code(body[-1]['tenantId'])
    @xero.organization_name(body[-1]['tenantName'])
    @xero.subscription_id(body[-1]['id'])
    @xero.save!
  end
end