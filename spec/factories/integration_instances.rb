FactoryGirl.define do
  factory :integration_instance do
    company
    filters  {{"location_id"=>["all"], "team_id"=>["all"], "employee_type"=>["all"]}}
  end

  factory :deputy_integration, parent: :integration_instance do
    api_identifier 'deputy'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'deputy')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:deputy_integration_inventory).id
    end
  end

  factory :peakon_integration, parent: :integration_instance do
    api_identifier 'peakon'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'peakon')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:peakon_integration_inventory).id
    end
  end

  factory :fifteen_five_integration, parent: :integration_instance do
    api_identifier 'fifteen_five'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'fifteen_five')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:fifteen_five_integration_inventory).id
    end
  end

  factory :paychex_integration, parent: :integration_instance do
    api_identifier 'paychex'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'paychex')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:paychex_integration_inventory).id
    end
  end

  factory :paylocity, parent: :integration_instance do
    api_identifier 'paylocity'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'paylocity')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:paylocity_integration_inventory).id
    end
  end

  factory :namely, parent: :integration_instance do
    api_identifier 'namely'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'namely')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:paylocity_integration_inventory).id
    end
  end

  factory :adp_wfn_us_integration, parent: :integration_instance do
    api_identifier 'adp_wfn_us'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'adp_wfn_us')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:adp_us_integration_inventory).id
    end

    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Client ID', value: '123', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Client Secret', value: '345', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Onboarding Templates', dropdown_options: nil, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Can Import Data', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Can Export Updation', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Enable Company Code', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Enable Tax Type', value: true, integration_instance_id: integration.id)
    end
  end

  factory :adp_wfn_can_integration, parent: :integration_instance do
    api_identifier 'adp_wfn_can'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'adp_wfn_can')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:adp_can_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Client ID', value: '123', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Client Secret', value: '345', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Onboarding Templates', dropdown_options: nil, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Can Import Data', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Can Export Updation', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Enable Company Code', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Enable Tax Type', value: true, integration_instance_id: integration.id)
    end
  end

  factory :team_spirit_integration, parent: :integration_instance do
    api_identifier 'team_spirit'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'team_spirit')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:team_spirit_integration_inventory).id
    end
  end

  factory :kallidus_learn, parent: :integration_instance do
    api_identifier 'kallidus_learn'
    name 'Instance No.1'
    state IntegrationInstance.states[:active]
    sync_status IntegrationInstance.sync_statuses[:succeed]

    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'kallidus_learn')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:kallidus_learn_integration_inventory).id
    end
  end

  factory :service_now_instance, parent: :integration_instance do
    api_identifier 'service_now'
    name 'ServiceNow'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'service_now')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:service_now_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Username', value: 'test', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Password', value: '123', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Domain', value: 'test.domain', integration_instance_id: integration.id)
    end
  end

  factory :bswift_instance, parent: :integration_instance do
    api_identifier 'bswift'
    name 'BSwift'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'bswift')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:bswift_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Username', value: 'test', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Password', value: '123', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Domain', value: 'test.domain', integration_instance_id: integration.id)
    end
  end

  factory :jazz_integration, parent: :integration_instance do
    api_identifier 'jazz_hr'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'jazz_hr')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:jazzhr_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Api Key', value: 'test-api1', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Client ID', value: '1234', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Client Secret', value: 'test123', integration_instance_id: integration.id)
    end
  end

  factory :workable_integration, parent: :integration_instance do
    api_identifier 'workable'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'workable')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:workable_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Subdomain', value: 'testsapling', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Access Token', value: '123', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Subscription Id', value: '1', integration_instance_id: integration.id)
    end
  end

  factory :smartrecruiters_integration, parent: :integration_instance do
    api_identifier 'smart_recruiters'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'smart_recruiters')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:smartrecruiters_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Client ID', value: '123', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Client Secret', value: '345', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Access Token', value: '1678', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Refresh Token', value: '4783', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Expires In', value: Time.now+200.days, integration_instance_id: integration.id)
    end
  end
  
  factory :workday_instance, parent: :integration_instance do
    api_identifier { 'workday' }
    name { 'Workday' }
    before(:create) do |integration_instance|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'workday')
      integration_instance.integration_inventory_id = integration_inventory.try(:id) || FactoryGirl.create(:workday_integration_inventory).id
    end
    after(:create) do |integration_instance|
      FactoryGirl.create(:integration_credential, name: 'User Name', value: 'test', integration_instance_id: integration_instance.id)
      FactoryGirl.create(:integration_credential, name: 'Password', value: '123', integration_instance_id: integration_instance.id)
      FactoryGirl.create(:integration_credential, name: 'Human Resource WSDL', value: 'human_resouce.wsdl', integration_instance_id: integration_instance.id)
      FactoryGirl.create(:integration_credential, name: 'Staffing WSDL', value: 'staffing.wsdl', integration_instance_id: integration_instance.id)
      FactoryGirl.create(:integration_credential, name: 'Document Category WID', value: '1t2e3s1t2', integration_instance_id: integration_instance.id)
    end
  end

  factory :bamboohr_integration, parent: :integration_instance do
    api_identifier 'bamboo_hr'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'bamboo_hr')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:bamboo_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Subdomain', value: 'sapling-sandbox', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Api Key', value: 'api_key', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Can Export New Profile', value: true, integration_instance_id: integration.id)
    end
  end

  factory :asana_instance, parent: :integration_instance do
    api_identifier { 'asana' }
    name { 'Instance No.1' }
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'asana')
      integration.integration_inventory_id = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:asana_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Asana Organization ID', value: 'xyz', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Asana Default Team', value: 'team', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Asana Personal Token', value: 'xyz', integration_instance_id: integration.id)
    end
  end

  factory :xero_instance, parent: :integration_instance do
    api_identifier { 'xero' }
    name { 'Instance No.1' }
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'xero')
      integration.integration_inventory_id = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:xero_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Company Code', value: '123', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Access Token', value: '456', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Refresh Token', value: 'def', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Organization Name', value: 'abc', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Expires In', value: '1', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Subscription Id', value: '789', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Payroll Calendar', value: 'test1', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Employee Group', value: 'xyz', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Pay Template', value: '1234', integration_instance_id: integration.id)
    end
  end

  factory :google_sso_integration_instance, parent: :integration_instance do
    api_identifier 'google_auth'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'google_auth')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:google_sso_integration_inventory).id
    end
  end

  factory :one_login_integration_instance, parent: :integration_instance do
    api_identifier 'one_login'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'one_login')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:one_login_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Enable Create Profile', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Enable Update Profile', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Sync Preferred Name', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Client ID', value: SecureRandom.hex, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Region', value: 'Test', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Client Secret', value: SecureRandom.hex, integration_instance_id: integration.id)
    end
  end

  factory :okta_integration_instance, parent: :integration_instance do
    api_identifier 'okta'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'okta')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:okta_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Enable Create Profile', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Enable Update Profile', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Identity Provider SSO Url', value: 'https://google.com', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Saml Certificate', value: '88787878787', integration_instance_id: integration.id)
    end
  end

  factory :ADFS_integration_instance, parent: :integration_instance do
    api_identifier 'active_directory_federation_services'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'active_directory_federation_services')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:ADFS_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Identity Provider SSO Url', value: 'https://google.com', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Saml Certificate', value: '88787878787', integration_instance_id: integration.id)
    end
  end

  factory :ping_id_integration_instance, parent: :integration_instance do
    api_identifier 'ping_id'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'ping_id')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:ping_id_integration_inventory).id
    end
  end

  factory :shibboleth_integration_instance, parent: :integration_instance do
    api_identifier 'shibboleth'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'shibboleth')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:shibboleth_integration_inventory).id
    end
  end

  factory :adfs_productivity_integration_instance, parent: :integration_instance do
    api_identifier 'adfs_productivity'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'adfs_productivity')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:adfs_productivity_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Access Token', value: SecureRandom.hex, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Refresh Token', value: SecureRandom.hex, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Expires In', value: (Time.now.utc+55.minutes).to_time, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Subdomain', value: 'Test', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Enable Update Profile', value: true, integration_instance_id: integration.id)
    end
  end

  factory :gsuite_integration_instance, parent: :integration_instance do
    api_identifier 'gsuite'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'gsuite')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:gsuite_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Gsuite Auth Credentials Present', value: 'Test', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Gsuite Account Url', value: 'Test', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Enable Update Profile', value: true, integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Link Gsuite Personal Email', value: true, integration_instance_id: integration.id)
    end
  end

  factory :slack_communication_integration_instance, parent: :integration_instance do
    api_identifier 'slack_communication'
    name 'Instance No.1'
    before(:create) do |integration|
      integration_inventory = IntegrationInventory.find_by(api_identifier: 'slack_communication')
      integration.integration_inventory_id  = integration_inventory.present? ? integration_inventory.id : FactoryGirl.create(:slack_communication_integration_inventory).id
    end
    after(:create) do |integration|
      FactoryGirl.create(:integration_credential, name: 'Webhook Url', value: 'example.com', integration_instance_id: integration.id)
      FactoryGirl.create(:integration_credential, name: 'Channel', value: 'Test', integration_instance_id: integration.id)
    end
  end
end
