require 'rails_helper'

RSpec.describe SAMLSettings, type: :controller do
	controller(ApiController) do
		include SAMLSettings

		def action
			respond_with saml_settings
		end

		def shib_action
			respond_with saml_shib_settings
		end
	end

	describe 'SamlStubController' do
		let(:company){ create(:company) }
		let!(:integration){ create(:okta_integration_instance, company: company)}

		before do
			integration.integration_credentials.find_by(name: 'Identity Provider SSO Url')&.update(value: 'xyz.com')
			integration.integration_credentials.find_by(name: 'Saml Certificate')&.update(value: 'abc213')
			company.stub(:authentication_type){ 'okta' }
			allow(controller).to receive(:current_company).and_return(company)
		end

		it 'should retun saml settings' do
			routes.draw { get "action" => "api#action" }
			response = get :action, format: :json
			parsed_response = JSON.parse(response.body)
			expect(parsed_response["assertion_consumer_service_binding"]).to eq("urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST")
			expect(parsed_response["idp_sso_target_url"]).to eq("xyz.com")
			expect(parsed_response["idp_cert"]).to eq("abc213")
			expect(parsed_response["assertion_consumer_service_url"]).to eq("https://test.host/api/v1/auth/omniauth_callbacks/consume_saml_response")
			expect(parsed_response["name_identifier_format"]).to eq("urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress")
		end

		context 'when authentication_type is set to ping' do

			before do
			  company.stub(:authentication_type){ 'ping_id' }
			end

			it 'should return issuer' do
				routes.draw { get "action" => "api#action" }
				response = get :action, format: :json
				parsed_response = JSON.parse(response.body)
				expect(parsed_response["issuer"]).to eq("https://test.host")
			end
			
		end

		context 'for shibboleth' do
			before do
				company.stub(:self_signed_attributes){ {'cert' => 'cert123', 'private_key' => 'pvt123'} }
			end
			it 'should retunr shibboleth specific attribtues' do
				routes.draw { get "shib_action" => "api#shib_action"}
				response = get :shib_action, format: :json
				parsed_response = JSON.parse(response.body)
				expect(parsed_response["name_identifier_format"]).to eq("urn:oasis:names:tc:SAML:2.0:nameid-format:transient")
				expect(parsed_response["issuer"]).to eq("https://test.host")
				expect(parsed_response["certificate"]).to eq("cert123")
				expect(parsed_response["private_key"]).to eq("pvt123")
			end
		end

	end
end
