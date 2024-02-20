require 'rails_helper'

RSpec.describe SsoIntegrationsService::ActiveDirectory::AuthenticateApplication do
  let(:company) { create(:company) }
  let!(:adfs) { create(:adfs_productivity_integration_instance, company: company) }

  before(:all) do
    WebMock.disable_net_connect!
  end

  describe '#authentication_request_url' do
    it 'should prepare_authetication_url' do
      allow_any_instance_of(Signet::OAuth2::Client).to receive(:authorization_uri).and_return('test')
      expect(::SsoIntegrationsService::ActiveDirectory::AuthenticateApplication.new(company).authentication_request_url).to eq ({:url=>"test"})
    end
  end

  describe '#authorize' do
    it 'should authorize integration if access_token is valid' do
      body = double('data', :message => 'OK', :parsed_response => {'access_token'=>'access_token', 'refresh_token'=>'refresh_token', 'expires_in'=>12}, :code => 200)
      allow_any_instance_of(SsoIntegrationsService::ActiveDirectory::AuthenticateApplication).to receive(:generate_access_token).and_return(body)
      ::SsoIntegrationsService::ActiveDirectory::AuthenticateApplication.new(company).authorize({code: '123'})
      expect(adfs.reload.access_token).to eq ('access_token')
      expect(adfs.reload.refresh_token).to eq ('refresh_token')
    end

    it 'should return 404 if access_token is invalid' do
      body = double('data', :message => 'NO_CONTENT', :parsed_response => {'access_token'=>'access_token', 'refresh_token'=>'refresh_token', 'expires_in'=>12}, :code => 404)
      allow_any_instance_of(SsoIntegrationsService::ActiveDirectory::AuthenticateApplication).to receive(:generate_access_token).and_return(body)

      ::SsoIntegrationsService::ActiveDirectory::AuthenticateApplication.new(company).authorize({code: '123'})
      expect(company.loggings.where(integration_name: 'Active Directory').last.action.include?("Generate access token - Failed")).to eq (true)
    end

    it 'should return 500 if there is some exception' do
      ::SsoIntegrationsService::ActiveDirectory::AuthenticateApplication.new(company).authorize({code: '123'})
      expect(company.loggings.where(integration_name: 'Active Directory').last.action.include?("Generate access token - Failed")).to eq (true)
    end
  end

  describe '#reauthorize' do
    it 'should reauthorize integration if access_token is valid' do
      body = double('data', :message => 'OK', :parsed_response => {'access_token'=>'access_token', 'refresh_token'=>'refresh_token', 'expires_in'=>12}, :code => 200)
      allow_any_instance_of(SsoIntegrationsService::ActiveDirectory::AuthenticateApplication).to receive(:generate_access_token).and_return(body)

      ::SsoIntegrationsService::ActiveDirectory::AuthenticateApplication.new(company).reauthorize
      expect(adfs.reload.access_token).to eq ('access_token')
      expect(adfs.reload.refresh_token).to eq ('refresh_token')
      end

    it 'should return 404 if access_token is invalid' do
      body = double('data', :message => 'NO_CONTENT', :parsed_response => {'access_token'=>'access_token', 'refresh_token'=>'refresh_token', 'expires_in'=>12}, :code => 404)
      allow_any_instance_of(SsoIntegrationsService::ActiveDirectory::AuthenticateApplication).to receive(:generate_access_token).and_return(body)

      ::SsoIntegrationsService::ActiveDirectory::AuthenticateApplication.new(company).reauthorize
      expect(company.loggings.where(integration_name: 'Active Directory').last.action.include?("Regenerate access token - Failed")).to eq (true)
    end

    it 'should return 500 if there is some exception' do
      ::SsoIntegrationsService::ActiveDirectory::AuthenticateApplication.new(company).reauthorize
      expect(company.loggings.where(integration_name: 'Active Directory').last.action.include?("Regenerate access token - Failed")).to eq (true)
    end
  end

end 