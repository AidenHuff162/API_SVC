require 'rails_helper'

RSpec.describe Api::V1::Admin::GsuiteAccountsController, type: :controller do
	let(:company){ create(:company) }
	let!(:gsuite){ create(:gsuite_integration_instance, company: company)}
	before do
		allow(controller).to receive(:current_company).and_return(company)
	end

	describe 'get_gsuite_auth_credential' do
		context 'not authorised with google' do
			before do
				authorizer = double("GSuite Authorizer")
				@auth_url="https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=force&client_id=dummyfortest&include_granted_scopes=true&redirect_uri=https://test.host/oauth2callback&response_type=code&scope=https://www.googleapis.com/auth/admin.directory.user&state=1"
				allow(authorizer).to receive(:get_authorization_url).and_return(@auth_url)
				allow(controller).to receive(:get_authorizer).and_return(controller.instance_eval {@authorizer = authorizer })
				allow(authorizer).to receive(:get_credentials_from_relation).and_return(nil)
			end
			it 'should redirect_to auth_url if not authorized earlier' do
				get :get_gsuite_auth_credential, format: :json
				expect(response).to redirect_to(@auth_url)
			end
		end

		context 'authorised with google' do
			before do
				authorizer = double("GSuite Authorizer")
				allow(controller).to receive(:get_authorizer).and_return(controller.instance_eval {@authorizer = authorizer })
				allow(authorizer).to receive(:get_credentials_from_relation).and_return({credentials: 'test_set'})
			end
			it 'should redirect_to some_url integrations page if authrozed' do
				get :get_gsuite_auth_credential, format: :json
				expect(response).to redirect_to("https://" + company.app_domain + "/#/admin/settings/integrations?goauthres=Account already authorized")
			end
		end
	end

	describe 'oauth2callback' do
		before do
			authorizer = double("GSuite Authorizer")
			allow(controller).to receive(:get_authorizer).and_return(controller.instance_eval {@authorizer = authorizer })
			allow(authorizer).to receive(:get_and_store_credentials_from_code_relation).and_return({credentials: 'test_set'})
		end
		context 'request with valid params' do
			before do
				get :oauth2callback, params: { state: company.id, code: rand(100..1000) }
			end
			it 'should set gsuite_auth_credentials_present to true' do
				expect(company.get_gsuite_account_info.gsuite_auth_credentials_present).to eq(true)
			end

			it 'should redirect_to integrations page with success message' do
				expect(response).to redirect_to("https://" + company.app_domain + "/#/admin/settings/integrations?goauthres=Successfully authroized with GSuite")
			end
		end
		context 'request with errors' do
			context 'request with no state param' do
				before do
					get :oauth2callback, params: { code: rand(100..1000) }
				end
				it 'should return 404 response' do
					expect(response.status).to eq(404)
				end
				it 'should return 404 response' do
					expect(company.get_gsuite_account_info.gsuite_auth_credentials_present).to eq(false)
				end
			end
			context 'request with no code' do
				it 'should keep gsuite_auth_credentials_present to false' do
					get :oauth2callback, params: { state: company.id }
					expect(company.get_gsuite_account_info.gsuite_auth_credentials_present).to eq(false)
				end
			end
		end
	end

	describe 'remove_credentials' do
		context 'with params' do
			before do
				authorizer = double("GSuite Authorizer")
				allow(controller).to receive(:get_authorizer).and_return(controller.instance_eval {@authorizer = authorizer })
				allow(authorizer).to receive(:get_credentials_from_relation).and_return({credentials: 'test_set'})
				allow(authorizer).to receive(:revoke_authorization_from_relation).and_return({response: true})
				company.get_gsuite_account_info.integration_credentials.find_by(name: 'Gsuite Auth Credentials Present').update(value: true)
				get :remove_credentials, params: { company_id: company.id }, format: :json
			end
			it 'should unauthorise accound with google' do
				expect(company.get_gsuite_account_info.gsuite_auth_credentials_present).to eq(false)
			end
			it 'should return status of 200' do
				expect(response.status).to eq(200)
			end
		end
		context 'missing params' do
			before do
				authorizer = double("GSuite Authorizer")
				allow(controller).to receive(:get_authorizer).and_return(controller.instance_eval {@authorizer = authorizer })
				allow(authorizer).to receive(:get_credentials_from_relation).and_return(nil)
				company.get_gsuite_account_info.integration_credentials.find_by(name: 'Gsuite Auth Credentials Present').update(value: true)
				get :remove_credentials, format: :json
			end
			it 'should not unauthorise the response' do
				expect(company.get_gsuite_account_info.gsuite_auth_credentials_present).to eq(true)
			end
		end
	end

end
