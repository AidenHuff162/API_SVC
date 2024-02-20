require 'rails_helper'
require 'attr_encrypted'
require 'cancan/matchers'

RSpec.describe Integration, type: :model do
  describe 'associations' do
  	it { should belong_to(:company) }
  	it { should have_many(:loggings).dependent(:nullify) }
  	it { should have_many(:field_histories) }
  end

  describe 'column specifications' do
    it { is_expected.to have_db_column(:company_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:api_name).of_type(:string) }
    it { is_expected.to have_db_column(:backup_api_key).of_type(:string) }
    it { is_expected.to have_db_column(:backup_secret_token).of_type(:string) }
    it { is_expected.to have_db_column(:channel).of_type(:string) }
    it { is_expected.to have_db_column(:is_enabled).of_type(:boolean).with_options(presence: true, default: false) }
    it { is_expected.to have_db_column(:webhook_url).of_type(:string) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:subdomain).of_type(:string) }
    it { is_expected.to have_db_column(:backup_signature_token).of_type(:string) }
    it { is_expected.to have_db_column(:backup_client_id).of_type(:string) }
    it { is_expected.to have_db_column(:api_company_id).of_type(:string) }
    it { is_expected.to have_db_column(:enable_create_profile).of_type(:boolean).with_options(presence: true, default: true) }
    it { is_expected.to have_db_column(:backup_client_secret).of_type(:string) }
    it { is_expected.to have_db_column(:company_code).of_type(:string) }
    it { is_expected.to have_db_column(:private_key_file).of_type(:string) }
    it { is_expected.to have_db_column(:public_key_file).of_type(:string) }
    it { is_expected.to have_db_column(:jira_issue_statuses).of_type(:string).with_options(default: [], array: true) }
    it { is_expected.to have_db_column(:jira_complete_status).of_type(:string).with_options(default: "Done") }
    it { is_expected.to have_db_column(:identity_provider_sso_url).of_type(:string) }
    it { is_expected.to have_db_column(:backup_saml_certificate).of_type(:text) }
    it { is_expected.to have_db_column(:saml_metadata_endpoint).of_type(:string) }
    it { is_expected.to have_db_column(:backup_access_token).of_type(:string) }
    it { is_expected.to have_db_column(:subscription_id).of_type(:string) }
    it { is_expected.to have_db_column(:gsuite_account_url).of_type(:string) }
    it { is_expected.to have_db_column(:gsuite_admin_email).of_type(:string) }
    it { is_expected.to have_db_column(:expires_in).of_type(:datetime) }
    it { is_expected.to have_db_column(:backup_refresh_token).of_type(:string) }
    it { is_expected.to have_db_column(:gsuite_auth_code).of_type(:string) }
    it { is_expected.to have_db_column(:gsuite_auth_credentials_present).of_type(:boolean).with_options(default: false) }
    it { is_expected.to have_db_column(:authentication_in_progress).of_type(:boolean).with_options(default: false) }
    it { is_expected.to have_db_column(:can_import_data).of_type(:boolean).with_options(default: false) }
    it { is_expected.to have_db_column(:encrypted_api_key).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_api_key_iv).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_secret_token).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_secret_token_iv).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_signature_token).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_signature_token_iv).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_access_token).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_access_token_iv).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_refresh_token).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_refresh_token_iv).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_client_id).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_client_id_iv).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_saml_certificate).of_type(:text) }
    it { is_expected.to have_db_column(:encrypted_saml_certificate_iv).of_type(:text) }
    it { is_expected.to have_db_column(:region).of_type(:string) }
    it { is_expected.to have_db_column(:enable_update_profile).of_type(:boolean).with_options(default: false) }
    it { is_expected.to have_db_column(:encrypted_slack_bot_access_token).of_type(:string) }
    it { is_expected.to have_db_column(:asana_organization_id).of_type(:string) }
    it { is_expected.to have_db_column(:asana_default_team).of_type(:string) }
    it { is_expected.to have_db_column(:asana_personal_token).of_type(:string) }
    it { is_expected.to have_db_column(:meta).of_type(:json).with_options(default: {}) }
    it { is_expected.to have_db_column(:iusername).of_type(:string) }
    it { is_expected.to have_db_column(:ipassword).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_iusername).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_iusername_iv).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_ipassword).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_ipassword_iv).of_type(:string) }
    it { is_expected.to have_db_column(:workday_human_resource_wsdl).of_type(:string) }
    it { is_expected.to have_db_column(:jira_issue_type).of_type(:string).with_options(default: "Task") }
    it { is_expected.to have_db_column(:bswift_auto_enroll).of_type(:boolean).with_options(default: false) }
    it { is_expected.to have_db_column(:bswift_benefit_class_code).of_type(:string) }
    it { is_expected.to have_db_column(:bswift_group_number).of_type(:string) }
    it { is_expected.to have_db_column(:bswift_hours_per_week).of_type(:string) }
    it { is_expected.to have_db_column(:bswift_relation).of_type(:string) }
    it { is_expected.to have_db_column(:bswift_hostname).of_type(:string) }
    it { is_expected.to have_db_column(:bswift_username).of_type(:string) }
    it { is_expected.to have_db_column(:bswift_password).of_type(:string) }
    it { is_expected.to have_db_column(:bswift_remote_path).of_type(:string) }
    it { is_expected.to have_db_column(:link_gsuite_personal_email).of_type(:boolean).with_options(default: true) }
    it { is_expected.to have_db_column(:can_export_updation).of_type(:boolean).with_options(default: true) }
    it { is_expected.to have_db_column(:enable_onboarding_templates).of_type(:boolean).with_options(default: false) }
    it { is_expected.to have_db_column(:onboarding_templates).of_type(:json).with_options(default: {}) }
    it { is_expected.to have_db_column(:encrypted_request_token).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_request_token_iv).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_request_secret).of_type(:string) }
    it { is_expected.to have_db_column(:encrypted_request_secret_iv).of_type(:string) }
    it { is_expected.to have_db_column(:organization_name).of_type(:string) }
    it { is_expected.to have_db_column(:payroll_calendar_id).of_type(:string) }
    it { is_expected.to have_db_column(:employee_group_name).of_type(:string) }
    it { is_expected.to have_db_column(:earnings_rate_id).of_type(:string) }
    it { is_expected.to have_db_column(:hiring_context).of_type(:string) }
    it { is_expected.to have_db_column(:last_sync).of_type(:datetime) }
    it { is_expected.to have_db_column(:can_delete_profile).of_type(:boolean) }
    it { is_expected.to have_db_column(:can_invite_profile).of_type(:boolean) }
    it { is_expected.to have_db_column(:slack_team_id).of_type(:string) }
    it { is_expected.to have_db_column(:can_invite_profile).of_type(:boolean) }
    it { is_expected.to have_db_column(:enable_company_code).of_type(:boolean) }
  end 
  
  describe 'ability' do
  	let(:company){ create(:company, subdomain: "abcc") }
  	let(:company2){ create(:company, subdomain: 'fang')}
		let(:one_login){ create(:integration, api_name: 'one_login', company: company) }
	  let(:one_login2){ create(:integration, api_name: 'one_login', company: company2) }

  	context 'account_owner' do
	  	let(:sarah){ create(:sarah, company: company) }
	  	subject(:ability) { Ability.new(sarah) }
	  	context 'should be able to manage integration' do
	  		it {should be_able_to(:manage, one_login)}
	  		context 'without integrations platform_visibility' do
	  			before do
	  				user_role = sarah.user_role
	  				user_role.permissions['admin_visibility']['integrations'] = 'no_access'
	  				user_role.save
	  			end
	  			subject(:ability) { Ability.new(sarah.reload) }
	  			it {should be_able_to(:manage, one_login)}
	  		end
	  	end
	  	context 'should not be able to manage integration' do
	  		it {should_not be_able_to(:manage, one_login2)}
	  	end
	  end
	  context 'admin user' do
	  	let(:peter){ create(:peter, company: company) }
	  	subject(:ability) { Ability.new(peter) }
	  	context 'should be able to manage integration with permission' do
	  		before do
	  			user_role = peter.user_role
	  			user_role.permissions['admin_visibility']['integrations'] = 'view_and_edit'
	  			user_role.save
	  		end
	  		it { should be_able_to(:manage, one_login )}
	  	end
	  	context 'should not be able to manage integration' do
	  		context 'with platform_visibility no_access' do
		  		before do
		  			user_role = peter.user_role
		  			user_role.permissions['admin_visibility']['integrations'] = 'no_access'
		  			user_role.save
		  		end
		  		it { should_not be_able_to(:manage, one_login) }
		  	end
		  	context 'belonging to other company' do
		  		it { should_not be_able_to(:manage, one_login2) }
		  	end
	  	end
	  end
	  context 'employee user' do
	  	let(:nick){ create(:nick, company: company) }
	  	subject(:ability) { Ability.new(nick) }
	  	context 'should not be able to manage any integration' do
	  		it { should_not be_able_to(:manage, one_login) }
	  		it { should_not be_able_to(:manage, one_login2)}
	  	end
	  end
  end
  
  describe 'callbacks' do
  	let(:company){ create(:company, subdomain: 'dang') }
  	let(:gsuite_api){ create(:integration, api_name: 'gsuite', company: company) }
  	let(:one_login){ create(:integration, api_name: 'one_login', company: company, enable_create_profile: true) }
    let(:okta){ create(:integration, api_name: 'okta', company: company, enable_create_profile: true) }
    let(:ping_id){ create(:integration, api_name: 'ping_id', company: company, enable_create_profile: true) }
    let(:namely){ create(:namely_integration, company: company) }
    let(:bamboo){ create(:bamboo_integration, company: company) }
    let(:google_auth){ create(:integration, api_name: 'google_auth', company: company) }
    let(:jira){ create(:integration, api_name: 'jira', channel: 'abc', company: company) }
    let(:active_directory_federation_services){ create(:integration, api_name: 'active_directory_federation_services', company: company) }
    let(:linkedin){ create(:linkedin_integration, company: company) }
    let(:workable){ create(:workable, company: company) }
  	let(:asana){create(:integration, api_name: 'asana', company: company) }
    let(:xero){create(:xero_integration, company: company) }
    let(:lever){create(:integration, api_name: 'lever', company: company) }
    let(:green_house){create(:integration, api_name: 'green_house', company: company) }
    let(:smart_recruiters){create(:integration, api_name: 'smart_recruiters', company: company) }
    let(:jazz_hr){create(:integration, api_name: 'jazz_hr', company: company) }
    let(:deputy){create(:integration, api_name: 'deputy', company: company) }
    let(:paylocity){create(:integration, api_name: 'paylocity', company: company) }
    let(:adp_wfn_can){create(:integration, api_name: 'adp_wfn_can', company: company) }
    let(:adp_wfn_us){create(:integration, api_name: 'adp_wfn_us', company: company) }

    context 'unauth_gsuite_account' do
  		it { is_expected.to callback(:unauth_gsuite_account).before(:destroy) }
  	end

  	context 'disable_sso' do
  		it 'should disable_sso on integration destroy' do
  			one_login.destroy
  			expect(company.reload.login_type).to eq('only_password')
  		end
  	end

    context 'update_sapling_departments_and_locations_from_namely' do
      # it 'should enque job for fetching details from namely' do
      #   size = Sidekiq::Queues["update_departments_and_locations"].size
      #   create(:integration, api_name: 'namely', company: company)
      #   expect(Sidekiq::Queues["update_departments_and_locations"].size).to eq(size + 2)
      # end
      # it 'should enque job for fetching details from namely if subdomain is changed' do
      #   namely.subdomain = "abc"
      #   size = Sidekiq::Queues["update_departments_and_locations"].size
      #   namely.save
      #   expect(Sidekiq::Queues["update_departments_and_locations"].size).to eq(size + 1)
      # end
      # it 'should enque job for fetching details from namely if secret token is changed' do
      #   namely.secret_token = "123"
      #   size = Sidekiq::Queues["update_departments_and_locations"].size
      #   namely.save
      #   expect(Sidekiq::Queues["update_departments_and_locations"].size).to eq(size + 1)
      # end
    end

    context 'update_sapling_departments_and_locations_from_namely if company is cruise' do
      # let(:company){ create(:company, subdomain: 'cruise') }
      # let(:namely){ create(:namely_integration, company: company) }

      # it 'should enque job for fetching details from namely' do
      #   size = Sidekiq::Queues["update_departments_and_locations"].size
      #   create(:namely_integration, company: company)
      #   expect(Sidekiq::Queues["update_departments_and_locations"].size).to eq(size + 4)
      # end

      # it 'should enque job for fetching details from namely if secret token is changed' do
      #   namely.secret_token = "123"
      #   size = Sidekiq::Queues["update_departments_and_locations"].size
      #   namely.save
      #   expect(Sidekiq::Queues["update_departments_and_locations"].size).to eq(size + 2)
      # end
    end
    
    context 'update_sapling_groups_from_bamboo' do
      # it 'should enque job for updating sapling group bamboo if subdomain is changed' do
      #   size = Sidekiq::Queues["update_departments_and_locations"].size
      #   create(:bamboo_integration, company: company)
      #   expect(Sidekiq::Queues["update_departments_and_locations"].size).to eq(size + 3)
      # end
      # it 'should enque job for updating sapling group bamboo if subdomain is changed' do
      #   bamboo.subdomain = "abc"
      #   size = Sidekiq::Queues["update_departments_and_locations"].size
      #   bamboo.save
      #   expect(Sidekiq::Queues["update_departments_and_locations"].size).to eq(size + 1)
      # end
      # it 'should enque job for updating sapling group bamboo if api key is changed' do
      #   bamboo.api_key = "abc"
      #   size = Sidekiq::Queues["update_departments_and_locations"].size
      #   bamboo.save
      #   expect(Sidekiq::Queues["update_departments_and_locations"].size).to eq(size + 1)
      # end
    end
    
    context 'disable_sso' do
      it 'should disable_sso if google auth is disabled' do
        google_auth.update(is_enabled: false)
        expect(company.reload.login_type).to eq('only_password')
      end
    end
    
    context 'clear_jira_integration' do
      it 'should clear jira integrations if channel is changed' do
        jira.update!(channel: 'def')
        expect(jira.jira_issue_statuses).to eq([])
      end
    end
    
    context 'disable_create_profile' do
      it 'should disable create profile after create if integration is one login' do
        one_login.save
        expect(one_login.reload.enable_create_profile).to eq(false)
      end
      it 'should disable create profile after create if integration is okta' do
        okta.save
        expect(okta.reload.enable_create_profile).to eq(false)
      end
      it 'should disable create profile after create if integration is ping_id' do
        ping_id.save
        expect(ping_id.reload.enable_create_profile).to eq(false)
      end
    end
  	
    context 'configure_asana' do
  		it 'should not throw errors in case of true response' do
	  		allow_any_instance_of(AsanaService::MockCall).to receive(:perform).and_return(true)
  			expect(asana.errors.full_messages.size).to eq(0)
  		end
  	end
    
    context 'clear_cache' do
      it { is_expected.to callback(:clear_cache).after(:commit) }
    end
    
    context 'ensure_multiple_ats' do
      it 'should ensure that multiple ats integration can be enabled at a time' do
        lever.save!
        workable.save!
        expect(Integration.where(api_name: ['lever', 'green_house', 'smart_recruiters', 'workable', 'jazz_hr', 'linked_in']).count).to eq(2)
        expect(Integration.where(api_name: ['lever', 'green_house', 'smart_recruiters', 'workable', 'jazz_hr', 'linked_in']).pluck(:api_name)).to eq(['lever', 'workable'])
      end
    end
   
    context 'ensure_unique_payroll' do
      it 'should ensure that only one payroll integration i.e. bamboo is enabled at a time' do
        xero.save!
        bamboo.save!
        expect(Integration.where(api_name: ['bamboo_hr', 'adp_wfn_us', 'adp_wfn_can', 'namely', 'paylocity', 'xero']).count).to eq(1)
        expect(Integration.where(api_name: ['bamboo_hr', 'adp_wfn_us', 'adp_wfn_can', 'namely', 'paylocity', 'xero']).pluck(:api_name)).to eq(['bamboo_hr'])
      end

      it 'should ensure that only one payroll integration i.e. adp_wfn_us is enabled at a time' do
        xero.save!
        adp_wfn_us.save!
        expect(Integration.where(api_name: ['bamboo_hr', 'adp_wfn_us', 'adp_wfn_can', 'namely', 'paylocity', 'xero']).count).to eq(1)
        expect(Integration.where(api_name: ['bamboo_hr', 'adp_wfn_us', 'adp_wfn_can', 'namely', 'paylocity', 'xero']).pluck(:api_name)).to eq(['adp_wfn_us'])
      end
    end
  	
    context 'ensure_unique_auth' do
  		it 'should remove previous method of auth after new integration' do
        one_login.save!
        okta.save
        expect(Integration.where(api_name: ['google_auth', 'shibboleth', 'active_directory_federation_services', 'okta', 'one_login', 'ping_id']).count).to eq(1)
        expect(Integration.where(api_name: ['google_auth', 'shibboleth', 'active_directory_federation_services', 'okta', 'one_login', 'ping_id']).pluck(:api_name)).to eq(['okta'])
  		end
  	end

    context 'clear_auth_cache after update' do
      it 'should clear cache and return false if integration is google_auth' do
        google_auth.update(access_token: '12345')
        expect(Rails.cache.exist?("#{google_auth.company_id}/authentication_type")).to eq(false)
      end
    end

    context 'clear_auth_cache before destroy' do
      it { is_expected.to callback(:clear_auth_cache).before(:destroy) }
    end


  	context 'clear_asana_ids' do
  		let(:workstream) { create(:workstream, company: company) }
  		let(:task) { create(:task, workstream: workstream) }
  		let(:nick){ create(:nick, company: company) }
  		let!(:tuc){ create(:task_user_connection, task: task, user: nick, asana_id: 'abcxyz') }
  		it 'should remove asana_id from tuc on destroy' do
  			allow_any_instance_of(AsanaService::MockCall).to receive(:perform).and_return(true)
  			expect { asana.destroy }.to change{ tuc.reload.asana_id }.to(nil)
  		end
  	end

    context 'log_asana_errors after rollback' do
      it { is_expected.to callback(:log_asana_errors).after(:rollback) }
    end

    context 'clear_payroll_cache after destroy' do
      it { is_expected.to callback(:clear_payroll_cache).after(:destroy) }
    end

    context 'manage_payroll_integration_change after destroy' do
      it { is_expected.to callback(:manage_payroll_integration_change).after(:destroy) }
    end

    context 'disable_on_linkedin after destroy' do
      it { is_expected.to callback(:disable_on_linkedin).after(:destroy) }
    end

    context 'update_sapling_option_mappings_from_adp' do
      it { is_expected.to callback(:update_sapling_option_mappings_from_adp).after(:create)}
    end
    
    context 'update_adp_onboarding_templates' do
      it { is_expected.to callback(:update_adp_onboarding_templates).after(:save)}
    end
  end

  describe 'encrypted_attributes' do
  	it 'should encrypted_saml_certificate for SAML' do
  		saml_certificate = 'asdasd123wd12eds12ewqdsc12ewqds' 
	  	integration = create(:integration, api_name: 'okta', 
	  	saml_certificate: 'asdasd123wd12eds12ewqdsc12ewqds')
	  	integration.save
	  	expect(integration.reload.encrypted_saml_certificate).to_not eq(nil)
	  	expect(integration.reload.encrypted_saml_certificate).to_not eq(saml_certificate)
  	end

  	it 'should encrypt remaning sensivite attributes' do
  		integration = create(:integration, api_name: 'test_integration', secret_token: '12312',
  			api_key: 'asdsad123edsadsd', signature_token: 'sdasdad12sad', access_token: '12sadasdsdsad',
  			slack_bot_access_token: 'asd12esadsad', refresh_token: 'asdasd', client_secret: '213asadsd',
  			client_id: '123asdsd', iusername: 'asdasd', ipassword: '123sadasd')
  			expect(integration.reload.encrypted_secret_token).to_not eq(nil)
  			expect(integration.reload.encrypted_api_key).to_not eq(nil)
  			expect(integration.reload.encrypted_signature_token).to_not eq(nil)
  			expect(integration.reload.encrypted_access_token).to_not eq(nil)
  			expect(integration.reload.encrypted_slack_bot_access_token).to_not eq(nil)
  			expect(integration.reload.encrypted_refresh_token).to_not eq(nil)
  			expect(integration.reload.encrypted_client_secret).to_not eq(nil)
  			expect(integration.reload.encrypted_client_id).to_not eq(nil)
  			expect(integration.reload.encrypted_iusername).to_not eq(nil)
  			expect(integration.reload.encrypted_ipassword).to_not eq(nil)
  			expect(integration.reload.encrypted_secret_token).to_not eq(integration.secret_token)
  			expect(integration.reload.encrypted_api_key).to_not eq(integration.api_key)
  			expect(integration.reload.encrypted_signature_token).to_not eq(integration.signature_token)
  			expect(integration.reload.encrypted_access_token).to_not eq(integration.access_token)
  			expect(integration.reload.encrypted_slack_bot_access_token).to_not eq(integration.slack_bot_access_token)
  			expect(integration.reload.encrypted_refresh_token).to_not eq(integration.refresh_token)
  			expect(integration.reload.encrypted_client_secret).to_not eq(integration.client_secret)
  			expect(integration.reload.encrypted_client_id).to_not eq(integration.client_id)
  			expect(integration.reload.encrypted_iusername).to_not eq(integration.iusername)
  			expect(integration.reload.encrypted_ipassword).to_not eq(integration.ipassword)
  	end
 	end	

  describe 'Validations' do
    let 'validate hiring_context uniqueness' do
      it { is_expected.to validate_uniqueness_of(:hiring_context) }
    end
  end

  describe 'okta_custom_fields' do
    let(:company) { create(:company) }
    let!(:integration) { create(:okta_integration, company: company ) }
    it 'should return okta custom fields with actual company id' do
      res = Integration.okta_custom_fields(company.id)
      expect(res.count).to eq(6)
    end

    it 'should return okta custom fields wit company id 53' do
      res = Integration.okta_custom_fields(53)
      expect(res.count).to eq(9)
    end
  end

  describe 'paylocity' do
    let!(:integration) { create(:paylocity_integration ) }
    it 'should return paylocity integrations' do
      res = Integration.paylocity
      expect(res.api_name).to eq("paylocity")
    end
  end

  describe 'unauth_gsuite_account' do
    let(:company) { create(:company) }
    let!(:integration) { create(:integration, company: company ) }
    it 'should return unauth gsuite account if present' do
      allow_any_instance_of(Google::Auth::UserAuthorizer).to receive(:get_credentials_from_relation).and_return(true)
      allow_any_instance_of(Google::Auth::UserAuthorizer).to receive(:revoke_authorization_from_relation).and_return(true)
      res = integration.unauth_gsuite_account
      expect(res).to eq(true)
    end
  end

  describe 'ensure_unique_provision' do
    let(:company) { create(:company) }
    let!(:integration) { create(:integration, company: company ) }
    it 'should ensure unique provision' do
      integration.ensure_unique_provision
      expect(company.integrations.count).to eq(1)
    end
  end

  describe 'generate_scrypt_client_id' do
    let(:company) { create(:company) }
    it 'should generate scrypt client id' do
      res = Integration.generate_scrypt_client_id(company)
      expect(res.present?).to eq(true)
    end
  end

  describe 'generate_scrypt_client_secret' do
    let(:company) { create(:company) }
    it 'should generate scrypt client secret' do
      res = Integration.generate_scrypt_client_secret(company)
      expect(res.present?).to eq(true)
    end
  end

  describe 'generate_api_token' do
    let(:company) { create(:company) }
    let!(:integration) { create(:integration, company: company ) }
    it 'should generate api token' do
      res = Integration.generate_api_token(company, integration.api_name)
      expect(res.present?).to eq(true)
    end
  end

  describe 'destroy' do
    let(:company) { create(:company) }
    let!(:deputy_integration) { create(:deputy_integration, company: company ) }
    it 'should clear provision cache' do
      deputy_integration.destroy
      expect(Rails.cache.fetch("#{deputy_integration.company_id}/provisioning_type")).to eq(nil)
    end
  end

  describe 'destroy' do
    let(:company) { create(:company) }
    let!(:integration) { create(:bamboo_integration, company: company ) }
    it 'should manage payroll integration change' do
      integration.destroy
    end
  end

  describe 'update' do
    let!(:integration) { create(:adp_integration) }
    it 'should manage company codes custom field' do
      integration.update(enable_company_code: true)
      expect(integration.enable_company_code).to eq(true)
    end
  end
end
