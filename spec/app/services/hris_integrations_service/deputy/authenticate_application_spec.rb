require 'rails_helper'

RSpec.describe HrisIntegrationsService::Deputy::AuthenticateApplication do
  let(:company) { create(:company, subdomain: 'deputy-company') }
  let!(:deputy) { create(:deputy_integration, company: company) }
  
  before(:all) do
    WebMock.disable_net_connect!
    @response = JSON.generate({'access_token'=>'access_token', 'refresh_token'=>'refresh_token', 'endpoint'=>'https://test.com', 'expires_in'=>12})
    @authcode = 123
  end

  before(:each) do
    @redirect_uri = "https://#{company.domain}/api/v1/deputy_authorize"
    allow_any_instance_of(IntegrationInstance).to receive(:client_id).and_return('id')
    allow_any_instance_of(IntegrationInstance).to receive(:client_secret).and_return('secret')
    allow_any_instance_of(IntegrationInstance).to receive(:client_secret).and_return('secret')
    allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return('access_token')
    allow_any_instance_of(IntegrationInstance).to receive(:refresh_token).and_return('refresh_token')
    allow_any_instance_of(IntegrationInstance).to receive(:subdomain).and_return('test.com')
  end
  
  describe '#authentication_request_url' do
    it 'should return auth URL' do
      url = HrisIntegrationsService::Deputy::AuthenticateApplication.new(company).authentication_request_url
      expect(url[:url]).to eq("https://once.deputy.com/my/oauth/login?client_id=#{deputy.client_id}&redirect_uri=#{@redirect_uri}&response_type=code&scope=longlife_refresh_token")
    end
  end

  describe '#authorize' do
    it 'should authorize and update deputy credentials in Sapling' do
      stub_request(:post, "https://once.deputy.com/my/oauth/access_token").
         with(
           body: {"client_id"=>deputy.client_id, "client_secret"=>deputy.client_secret, "code"=>@authcode, "grant_type"=>"authorization_code", "redirect_uri"=>@redirect_uri, "scope"=>"longlife_refresh_token"},
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/x-www-form-urlencoded',
          'Host'=>'once.deputy.com',
          'User-Agent'=>'Ruby'
           }).
         to_return(status: [200, 'OK'], body: @response)

      response = ::HrisIntegrationsService::Deputy::AuthenticateApplication.new(company).authorize(@authcode)
      expect(response).to eq('success')
      expect(deputy.reload.access_token).to eq('access_token')
      expect(deputy.refresh_token).to eq('refresh_token')
      expect(deputy.subdomain).to eq('test.com')
    end

    it 'should not authorize if credentials are invalid' do
      allow_any_instance_of(IntegrationInstance).to receive(:client_secret).and_return(nil)
      stub_request(:post, "https://once.deputy.com/my/oauth/access_token").
         with(
           body: {"client_id"=>deputy.client_id, "client_secret"=>deputy.client_secret, "code"=>@authcode, "grant_type"=>"authorization_code", "redirect_uri"=>@redirect_uri, "scope"=>"longlife_refresh_token"},
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/x-www-form-urlencoded',
          'Host'=>'once.deputy.com',
          'User-Agent'=>'Ruby'
           }).
         to_return(status: 401, body: @response)

      ::HrisIntegrationsService::Deputy::AuthenticateApplication.new(company).authorize(@authcode)
      logging = company.loggings.where(integration_name: 'Deputy').last
      expect(logging.state).to eq(401)
      expect(logging.action).to eq("Generate access token - Failed")
    end
    
    it 'should not authorize if there is some exception while authorizing' do
      ::HrisIntegrationsService::Deputy::AuthenticateApplication.new(company).authorize(@authcode)
      logging = company.loggings.where(integration_name: 'Deputy').last
      expect(logging.state).to eq(500)
      expect(logging.action).to eq("Generate access token - Failed")
    end
  end

  describe '#reauthorize' do
    it 'should rearuthorize' do
      stub_request(:post, "https://test.domain/oauth/access_token").
        with(
          body: {"client_id"=>deputy.client_id, "client_secret"=>deputy.client_secret, "grant_type"=>"refresh_token", "redirect_uri"=>@redirect_uri, "refresh_token"=>nil, "scope"=>"longlife_refresh_token"},
          headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/x-www-form-urlencoded',
          'Host'=>'test.domain',
          'User-Agent'=>'Ruby'
           }).
        to_return(status: [200, 'OK'], body: @response)

      HrisIntegrationsService::Deputy::AuthenticateApplication.new(company).reauthorize
      expect(deputy.reload.access_token).to eq('access_token')
      expect(deputy.refresh_token).to eq('refresh_token')
      expect(deputy.subdomain).to eq('test.com')
    end

    it 'should not authorize if credentials are invalid' do
      stub_request(:post, "https://test.com/oauth/access_token").
        to_return(status: 401, body: @response)

      ::HrisIntegrationsService::Deputy::AuthenticateApplication.new(company).reauthorize
      
      logging = company.loggings.where(integration_name: 'Deputy').last
      expect(logging.state).to eq(401)
      expect(logging.action).to eq("Regenerate access token - Failed")
    end
    
    it 'should not authorize if there is some exception while authorizing' do
      ::HrisIntegrationsService::Deputy::AuthenticateApplication.new(company).reauthorize
      logging = company.loggings.where(integration_name: 'Deputy').last
      expect(logging.state).to eq(500)
      expect(logging.action).to eq("Regenerate access token - Failed")
    end
  end

end
