require 'rails_helper'

RSpec.describe HrisIntegrationsService::Xero::InitializeApplication do
  let(:company) { create(:company) }
  let(:xero_integration_inventory) {create(:integration_inventory, display_name: 'Xero', status: 2, category: 0, data_direction: 1, enable_filters: false, api_identifier: 'xero')}
  let(:xero) {create(:integration_instance, api_identifier: 'xero', state: 'active', integration_inventory_id: xero_integration_inventory.id, name: 'Instance no.1', company_id: company.id)}
  let(:pto_policy) { create(:default_pto_policy, xero_leave_type_id: '123', company: company) } 
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) } 
  let(:pto_reqeust) { create(:default_pto_request, user: user, pto_policy: pto_policy) } 

  before(:all) do
    WebMock.disable_net_connect!
  end

  describe '#update_request_token' do
    it 'should update request token in sapling' do
      callback_url = "https://#{company.domain}/api/v1/admin/onboarding_integrations/xero/authorize"
      state = JsonWebToken.encode({company_id: company.id, instance_id: nil, user_id: nil})
      expect_any_instance_of(HrisIntegrationsService::Xero::InitializeApplication).to receive(:authorize_app_url) {"https://login.xero.com/identity/connect/authorize?response_type=code&client_id=#{ENV['XERO_CLIENT_ID']}&redirect_uri=#{callback_url}&scope=offline_access payroll.employees payroll.settings accounting.settings&state=#{state}"}
      url = HrisIntegrationsService::Xero::InitializeApplication.new(company, 'test', "1").authorize_app_url
      event_url = "https://login.xero.com/identity/connect/authorize?response_type=code&client_id=#{ENV['XERO_CLIENT_ID']}&redirect_uri=#{callback_url}&scope=offline_access payroll.employees payroll.settings accounting.settings&state=#{state}"
      expect(url).to eq(event_url)
    end
  end

  describe '#authorize_request_token' do
    it 'should authorize_request_token token in sapling' do
      xero.access_token("123")
      xero.refresh_token("222")
      allow_any_instance_of(HrisIntegrationsService::Xero::InitializeApplication).to receive(:get_xero_tenant_id) {true}

      stub_request(:post, "https://identity.xero.com/connect/token").
        with(
          body: {"code"=>"", "grant_type"=>"authorization_code", "redirect_uri"=>"https://#{company.domain}/api/v1/admin/onboarding_integrations/xero/authorize"},
          headers: {
          'Authorization'=>"Basic #{Base64.strict_encode64(ENV['XERO_CLIENT_ID'] + ':' + ENV['XERO_CLIENT_SECRET'])}",
          'Content-Type'=>'application/x-www-form-urlencoded'
           }).
      to_return(status: 200, body: JSON.generate({access_token: '111', refresh_token: '123'}), headers: {})

      HrisIntegrationsService::Xero::InitializeApplication.new(company, 'test', "1").save_access_token
      expect(xero.reload.access_token).not_to eq('123')
      expect(xero.reload.refresh_token).not_to eq('222')
    end
  end
end