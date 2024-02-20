require 'rails_helper'

RSpec.describe HrisIntegrationsService::Deputy::ManageDeputyCompanies do
  let(:company) { create(:company, subdomain: 'deputy-company') }
  let!(:deputy) { create(:deputy_integration, company: company) }
  
  before(:all) do
    WebMock.disable_net_connect!
    @response = JSON.generate([{'CompanyName'=>'test'}])
  end

  before(:each) do
    allow_any_instance_of(IntegrationInstance).to receive(:client_id).and_return('id')
    allow_any_instance_of(IntegrationInstance).to receive(:client_secret).and_return('secret')
    allow_any_instance_of(IntegrationInstance).to receive(:client_secret).and_return('secret')
    allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return('access_token')
    allow_any_instance_of(IntegrationInstance).to receive(:refresh_token).and_return('refresh_token')
    allow_any_instance_of(IntegrationInstance).to receive(:subdomain).and_return('test.domain')
  end

  describe '#create_deputy_company' do
    it 'should create loation in Sapling' do
      stub_request(:get, "https://test.domain/api/v1/resource/Company").
        to_return(status: [200, 'OK'], body: @response)

      ::HrisIntegrationsService::Deputy::ManageDeputyCompanies.new.create_deputy_company(deputy)
      expect(company.locations.last.name).to eq('test')
    end

    it 'should not create location in Sapling if invalid credentials' do
    allow_any_instance_of(IntegrationInstance).to receive(:client_id).and_return(nil)
      stub_request(:get, "https://test.domain/api/v1/resource/Company").
        to_return(status: 401, body: @response)
        
      ::HrisIntegrationsService::Deputy::ManageDeputyCompanies.new.create_deputy_company(deputy)
      logging = company.loggings.where(integration_name: 'Deputy').last
      expect(logging.state).to eq(401)
      expect(logging.action).to eq("Fetch deputy locations (companies) - Failure")
    end

    it 'should not create locations if there is some exception while authorizing' do
      ::HrisIntegrationsService::Deputy::ManageDeputyCompanies.new.create_deputy_company(deputy)
      logging = company.loggings.where(integration_name: 'Deputy').last
      expect(logging.state).to eq(500)
      expect(logging.action).to eq("Fetch deputy locations (companies) - Failure")
    end
  end
end
