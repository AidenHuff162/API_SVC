require 'rails_helper'

RSpec.describe Api::V1::Admin::OnboardingIntegrations::XeroController, type: :controller do
  let(:company) { create(:company, subdomain: 'xero') }
  let(:super_admin) { create(:user, company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(super_admin)
    allow(controller).to receive(:current_company).and_return(company)

  end

  describe 'get #new' do
    before do
      @authorize_url_data = 'https://api/xero.com&scope=payroll.employees,payroll.settings,payroll.payitems,payroll.payrollcalendars,payroll.leaveapplications'
    end
    
    it 'should return ok status, Authorize URL' do 
      allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
      expect_any_instance_of(HrisIntegrationsService::Xero::InitializeApplication).to receive(:authorize_app_url) { @authorize_url_data }
      get :new, format: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)["url"]).to eq("https://api/xero.com&scope=payroll.employees,payroll.settings,payroll.payitems,payroll.payrollcalendars,payroll.leaveapplications")
    end
  end

  describe 'get #authorize' do
    it 'should return ok status and Redirect URL' do 
      allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
      expect_any_instance_of(HrisIntegrationsService::Xero::Helper).to receive(:verify_state_and_fetch_company) {company}
      expect_any_instance_of(HrisIntegrationsService::Xero::InitializeApplication).to receive(:save_access_token) {true}
      get :authorize, format: :json
      expect(response.status).to eq(302)
      expect(response).to redirect_to("http://#{company.app_domain}/#/admin/settings/integrations?map=xero&response=success")
    end

    it 'should return unauthorized status if state is invalid' do 
      get :authorize, format: :json
      expect(response.status).to eq(401)
    end

    it 'should return 302 status and xero failure if unable to authorize' do 
      expect_any_instance_of(HrisIntegrationsService::Xero::Helper).to receive(:verify_state_and_fetch_company) {company}
      expect_any_instance_of(HrisIntegrationsService::Xero::InitializeApplication).to receive(:save_access_token) {false}
      get :authorize, format: :json
      expect(response.status).to eq(302)
      expect(response).to redirect_to("http://#{company.app_domain}/#/admin/settings/integrations?map=xero&response=failure")
    end
  end
  
  describe 'get #get_organisations' do
    let!(:xero) { create(:xero_integration, expires_in: company.time, company: company)}
    before do
      @organisation = [{"Name"=>"Demo Company (AU)", "LegalName"=>"Demo Company (AU)", "PaysTax"=>true, "Version"=>"AU", "OrganisationType"=>"COMPANY"}]
    end

    it 'should return ok status and Organisation' do 
      allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
      expect_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:fetch_organisations) {@organisation}
      get :get_organisations
      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body.count).to eq(1)
      expect(body[0]["Name"]).to eq("Demo Company (AU)")
      expect(body[0]["OrganisationType"]).to eq("COMPANY")
    end
  end

  describe 'get #get_payroll_calendars' do
    let!(:xero) { create(:xero_integration, expires_in: company.time, company: company)}
    before do
      @payroll_calendars = [{"PayrollCalendarID"=>"c9dc5f89-1951-4f70-b367-b7f45d205e01", "Name"=>"Fortnightly Calendar", "CalendarType"=>"FORTNIGHTLY"}]
    end

    it 'should return ok status and Payroll Calendars' do 
      allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
      expect_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:fetch_payroll_calendars) {@payroll_calendars}
      get :get_payroll_calendars
      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body.count).to eq(1)
      expect(body[0]["Name"]).to eq("Fortnightly Calendar")
      expect(body[0]["CalendarType"]).to eq("FORTNIGHTLY")
    end
  end

  describe 'get #get_employee_group_names' do
    let!(:xero) { create(:xero_integration, expires_in: company.time, company: company)}
    before do
      @employee_groups = [{"Name"=>"Region", "Status"=>"ACTIVE", "Options"=>[{"Name"=>"Eastside", "Status"=>"ACTIVE"}, {"Name"=>"North", "Status"=>"ACTIVE"}]}]
    end

    it 'should return ok status and employee group names' do 
      allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
      expect_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:fetch_employee_groups) {@employee_groups}
      get :get_employee_group_names
      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body.count).to eq(1)
      expect(body[0]["Options"].count).to eq(2)
      expect(body[0]["Options"][0]["Name"]).to eq("Eastside")
      expect(body[0]["Options"][1]["Name"]).to eq("North")
    end
  end

  describe 'get #get_pay_templates' do
    let!(:xero) { create(:xero_integration, expires_in: company.time, company: company)}
    before do
      @pay_templates = [{"EarningsRateID"=>"9cd63fd3-d923-4dff-a57a-164633a2541f", "Name"=>"Ordinary Hours"}, {"EarningsRateID"=>"f89c4ed4-8dd9-47ee-86af-a437c3920289", 
        "Name"=>"Allowances subject to tax withholding and super"}, {"EarningsRateID"=>"bd182c24-5fa6-4725-ba8d-4e55440c02cd", "Name"=>"Allowances exempt from tax withholding and super"}]

    end

    it 'should return ok status and pay templates' do 
      allow(controller).to receive(:current_company).and_return(controller.instance_eval {@current_company = current_company })
      expect_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:fetch_pay_templates) {@pay_templates}
      get :get_pay_templates
      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body.count).to eq(3)
      expect(body[0]["Name"]).to eq("Ordinary Hours")
      expect(body[1]["Name"]).to eq("Allowances subject to tax withholding and super")
      expect(body[2]["Name"]).to eq("Allowances exempt from tax withholding and super")
    end
  end

end
 