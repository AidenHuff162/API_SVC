FactoryGirl.define do
  factory :integration do
    after(:build) { |integration| integration.class.skip_callback(:create, :before, :configure_asana, raise: false) }
  end

  factory :namely_integration, parent: :integration do
    company
    is_enabled :true
    secret_token ENV['TESTCASE_NAMELY_SECRET_TOKEN']
    api_name :namely
    subdomain :'sapling-sandbox'
  end

  factory :asana_integration, parent: :integration do
    company
    asana_default_team :'team'
    is_enabled :true
    asana_personal_token :xyz
    asana_organization_id :xyz
    api_name :asana
  end

  factory :bamboo_integration, parent: :integration do
    company
    is_enabled :true
    secret_token ENV['TESTCASE_BAMBOO_SECRET_TOKEN']
    api_name :bamboo_hr
    api_key 'api_key' 
    subdomain :'sapling-sandbox'    
  end

  factory :workable, parent: :integration do
    company
    is_enabled :true
    api_name :workable
    subdomain :'sapling-sandbox'
    access_token :abcdefgh1234
    subscription_id 123 
  end
  
  factory :slack_integration, parent: :integration do
    company
    is_enabled :true
    api_name :slack_notification
  end
  
  factory :linked_in_integration, parent: :integration do
    secret_token ENV['TESTCASE_BAMBOO_SECRET_TOKEN']
    api_name :linked_in
    hiring_context { Faker::Name.title }
  end

  factory :adp_integration, parent: :integration do
    company
    client_id 'client_id'
    client_secret 'client_secret'
    api_name :adp_wfn_us
  end
  
  factory :xero_integration, parent: :integration do
    company
    is_enabled :true
    api_name :xero
  end

  factory :linkedin_integration, parent: :integration do
    secret_token ENV['TESTCASE_BAMBOO_SECRET_TOKEN']
    api_name :linked_in
    hiring_context { Faker::Name.title }

    company
  end
  
  factory :jira_integration, parent: :integration do
    company
    client_id ENV['TESTCASE_BAMBOO_SECRET_TOKEN']
    client_secret ENV['TESTCASE_BAMBOO_SECRET_TOKEN']
    is_enabled :true
    secret_token ENV['TESTCASE_BAMBOO_SECRET_TOKEN']
    api_name :jira
    api_key 'jira' 
  end

  factory :lever_integration, parent: :integration do
    company
    is_enabled :true
    signature_token ENV['TESTCASE_BAMBOO_SECRET_TOKEN']
    api_name :lever
    api_key 'lever' 
  end
  
  factory :paylocity_integration, parent: :integration do
    api_name 'paylocity'
  end

  factory :smart_recruiters_integration, parent: :integration do
    company
    api_name 'smart_recruiters'
    client_secret 'client_secret'
    client_id 'client_id'
    access_token :abcdefgh1234
    expires_in Time.now + 5000
    refresh_token 'refresh_token'
  end
  
  factory :okta_integration, parent: :integration do
    company
    is_enabled :true
    identity_provider_sso_url 'https://google.com'
    api_name :okta
    api_key 'lever' 
    secret_token 'secret'
    enable_update_profile true
  end

  factory :one_login_integration, parent: :integration do
    company
    is_enabled :true
    api_name :one_login
  end

  factory :adfs_integration, parent: :integration do
    company
    is_enabled :true
    api_name :adfs_productivity
  end

  factory :workday_integration, parent: :integration do
    company
    is_enabled :true
    api_name :workday     
  end
end
