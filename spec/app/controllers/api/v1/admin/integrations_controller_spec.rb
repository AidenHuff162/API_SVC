require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Api::V1::Admin::IntegrationsController, type: :controller do
	let(:company){ create(:company) }
	let(:sarah){ create(:user, company: company) }

	before do
		allow(controller).to receive(:current_company).and_return(company)
		allow(controller).to receive(:current_user).and_return(sarah)
		@full_serializer_keys = ["id", "api_name", "api_key", "secret_token", "channel", "is_enabled", "webhook_url",
			"subdomain", "signature_token", "enable_create_profile", "client_id", "api_company_id", "client_secret",
			"company_code", "public_key_file_url", "jira_issue_type", "jira_issue_statuses", "jira_complete_status",
			"identity_provider_sso_url", "saml_certificate", "saml_metadata_endpoint", "subscription_id", "access_token",
			"gsuite_account_url", "gsuite_admin_email", "gsuite_auth_credentials_present", "encrypted_secret_token",
			"encrypted_api_key", "encrypted_signature_token", "encrypted_client_secret", "encrypted_access_token",
			"can_import_data", "region", "enable_update_profile", "asana_organization_id", "asana_default_team",
			"asana_personal_token", "encrypted_iusername", "encrypted_ipassword", "iusername", "ipassword",
			"workday_human_resource_wsdl", "meta", "link_gsuite_personal_email", "can_export_updation",
			"hiring_context", "encrypted_request_token", "enable_onboarding_templates", "employee_group_name",
			"payroll_calendar_id", "earnings_rate_id", "get_last_sync_date", "get_last_sync_time", "can_invite_profile", "can_delete_profile",
			"is_deputy_authenticated", "is_adfs_authenticated", "enable_company_code", "enable_international_templates", "get_last_sync_status",
			'enable_tax_type', 'sync_preferred_name']
	end

	describe '#index' do
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return 401 status' do
				get :index, params: { sub_tab: 'integrations' }, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			let!(:integration){ create(:integration, company: company, api_name: 'onelogin') }
			let!(:integration2){ create(:integration, company: company, api_name: 'gsuite')}
			it 'should return 200 status' do
				get :index, params: { sub_tab: 'integrations' }, format: :json
				expect(response.status).to eq(200)
				expect(JSON.parse(response.body).size).to eq(2)
				expect(JSON.parse(response.body).first.keys).to eq(@full_serializer_keys)
			end
			context 'user not having permission' do
				before do
					user_role = sarah.user_role
		  		user_role.permissions['admin_visibility']['integrations'] = 'no_access'
		  		user_role.save
				end
				it 'should not return requested data' do
					get :index, params: { sub_tab: 'integrations' }, format: :json
					expect(response.status).to eq(204)
					expect(response.body).to eq("")
				end
			end
		end
	end
	describe '#create' do
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return 401 response' do
				post :create, params: { regions: ["US", "EU"], identity_provider_sso_url: 'http://abc.xuz.com',
				saml_certificate: 'asdsadp21eas12e12ew12e', api_name: 'okta' }, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			it 'should create an integration' do
				post :create, params: { regions: ["US", "EU"], identity_provider_sso_url: 'http://abc.xuz.com',
				saml_certificate: 'asdsadp21eas12e12ew12e', api_name: 'okta' }, format: :json
				expect(response.status).to eq(201)
				expect(Integration.count).to eq(1)
				expect(JSON.parse(response.body).keys).to eq(@full_serializer_keys)
			end
		end
	end
	describe '#update' do
		let(:integration){ create(:integration, company: company, api_name: 'okta',
		saml_certificate: 'sadad12e12es1e122ew', identity_provider_sso_url: 'http://abc.xuz.com') }
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return with 401 status' do
				put :update, params: { id: integration.id, saml_certificate: 'kiacamoqwesae1q' }, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			it 'should update the integration' do
				put :update, params: { id: integration.id, saml_certificate: 'kiacamoqwesae1q' }, format: :json
				expect(response.status).to eq(200)
				expect(integration.reload.saml_certificate).to eq('kiacamoqwesae1q')
				expect(JSON.parse(response.body).keys).to eq(@full_serializer_keys)
			end
		end
	end
	describe '#destroy' do
		let(:integration){ create(:integration, company: company, api_name: 'okta',
		saml_certificate: 'sadad12e12es1e122ew', identity_provider_sso_url: 'http://abc.xuz.com') }
		context 'unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return with 401 response' do
				delete :destroy, params: { id: integration.id }, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'authenticated user' do
			context 'with correct params' do
				it 'should remove integration' do
					delete :destroy, params: { id: integration.id }, format: :json
					expect(response.status).to eq(200)
					expect(Integration.count).to eq(0)
				end
			end
			context 'for slack integration' do
				let(:slack){ create(:integration, api_name: 'slack_notification', company: company) }
				let!(:nick){ create(:nick, company: company, slack_notification: true) }
				it 'should unauth and destroy slack integration' do
					Sidekiq::Testing.inline! do
						delete :destroy, params: { id: slack.id }, format: :json
						expect(response.status).to eq(200)
						expect(nick.reload.slack_notification).to eq(false)
						expect(nick.reload.email_notification).to eq(true)
						expect(Integration.count).to eq(0)
					end
				end
			end
		end
	end
	describe '#check_slack_integration' do
		context 'for unauthenticated user' do
			before do
				allow(controller).to receive(:current_user).and_return(nil)
			end
			it 'should return 401 status' do
				get :check_slack_integration, format: :json
				expect(response.status).to eq(401)
			end
		end
		context 'for authenticated user' do
			context 'company not having slack integration' do
				it 'should return status of 204' do
					get :check_slack_integration, format: :json
					expect(response.status).to eq(204)
				end
			end
			context 'company having slack integration' do
				let!(:slack_integration){ create(:integration, api_name: 'slack_notification', company: company)}
				it 'should return slack_integration' do
					get :check_slack_integration, format: :json
					expect(response.status).to eq(200)
					expect(JSON.parse(response.body)['api_name']).to eq('slack_notification')
					expect(JSON.parse(response.body).keys).to eq(['api_name', 'saml_certificate', 'identity_provider_sso_url'])
				end
			end
		end
	end
end
