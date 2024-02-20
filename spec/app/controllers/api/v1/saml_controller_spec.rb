require 'rails_helper'

RSpec.describe Api::V1::SamlController, type: :controller do
	let(:company){ create(:company) }

	before do
		allow(controller).to receive(:current_company).and_return(company)
	end

	describe 'get init' do
		before do
			requestObj = double('OneLoginRequestObject')
			allow(OneLogin::RubySaml::Authrequest).to receive(:new).and_return(requestObj)
			allow(requestObj).to receive(:create).and_return('https://samlloginrequest.com')
			allow(controller).to receive(:saml_settings).and_return('dummy_settings')
		end
		context 'with saml credentials present' do
			let!(:integration){ create(:okta_integration_instance, company: company) }

			it 'should send and authn request' do
				integration.integration_credentials.find_by(name: 'Identity Provider SSO Url')&.update(value: 'https://dumy.cim')
				integration.integration_credentials.find_by(name: 'Saml Certificate')&.update(value: 'adasdadasdakad-1203-312wqdq32r213r24ewr31')

				expect(get :init).to redirect_to('https://samlloginrequest.com')
			end
		end
		context 'without SAML credentials present' do
			let!(:integration){ create(:okta_integration_instance, company: company) }
			it 'should redirect_to login page' do
				integration.integration_credentials.find_by(name: 'Saml Certificate')&.update(value: nil)
				expect(get :init).to redirect_to("https://#{company.app_domain}/#/login?error=Missing configurations")
			end
		end
	end

end
