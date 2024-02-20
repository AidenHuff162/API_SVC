FactoryGirl.define do
  factory :integration_inventory do
  end

  factory :deputy_integration_inventory, parent: :integration_inventory do
    display_name 'Deputy'
    status 2
    category 4
    data_direction 0
    enable_filters true
    api_identifier 'deputy'
    enable_authorization true
  end

  factory :peakon_integration_inventory, parent: :integration_inventory do
    display_name 'Peakon'
    status 2
    category 6
    data_direction 0
    enable_filters true
    api_identifier 'peakon'
    enable_authorization true
  end

  factory :fifteen_five_integration_inventory, parent: :integration_inventory do
    display_name '15Five'
    status 2
    category 6
    data_direction 0
    enable_filters true
    api_identifier 'fifteen_five'
    enable_authorization true
  end


  factory :paychex_integration_inventory, parent: :integration_inventory do
    display_name 'Paychex'
    status 2
    category 1
    data_direction 0
    enable_filters true
    api_identifier 'paychex'
    enable_authorization true
  end

  factory :paylocity_integration_inventory, parent: :integration_inventory do
    display_name 'Paylocity'
    status 2
    category 1
    data_direction 0
    enable_filters true
    api_identifier 'paylocity'
    enable_authorization true
  end

  factory :namely_integration_inventory, parent: :integration_inventory do
    display_name 'Namely'
    status 2
    category 1
    data_direction 0
    enable_filters true
    api_identifier 'Namely'
    enable_authorization true
  end

  factory :bamboo_integration_inventory, parent: :integration_inventory do
    display_name 'BambooHR'
    status 2
    category 1
    data_direction 0
    enable_filters false
    api_identifier 'bamboo_hr'
    enable_authorization false
  end

  factory :adp_us_integration_inventory, parent: :integration_inventory do
    display_name 'ADP WFN US'
    status 2
    category 1
    data_direction 0
    enable_filters true
    api_identifier 'adp_wfn_us'
    enable_authorization false
  end

  factory :adp_can_integration_inventory, parent: :integration_inventory do
    display_name 'ADP WFN CAN'
    status 2
    category 1
    data_direction 0
    enable_filters true
    api_identifier 'adp_wfn_can'
    enable_authorization false
  end

  factory :learn_upon_integration_inventory, parent: :integration_inventory do
    display_name 'LearnUpon'
    status 2
    category 5
    data_direction 0
    enable_filters true
    api_identifier 'learn_upon'
    enable_authorization false
  end

  factory :lessonly_integration_inventory, parent: :integration_inventory do
    display_name 'Lessonly'
    status 2
    category 5
    data_direction 0
    enable_filters true
    api_identifier 'lessonly'
    enable_authorization false
  end

  factory :trinet_integration_inventory, parent: :integration_inventory do
    display_name 'Trinet'
    status 2
    category 1
    data_direction 0
    enable_filters true
    api_identifier 'trinet'
    enable_authorization false
  end

  factory :gusto_integration_inventory, parent: :integration_inventory do
    display_name 'Gusto'
    status 2
    category 1
    data_direction 0
    enable_filters true
    api_identifier 'gusto'
    enable_authorization false
  end

  factory :lattice_integration_inventory, parent: :integration_inventory do
    display_name 'Lattice'
    status 2
    category 6
    data_direction 0
    enable_filters true
    api_identifier 'lattice'
    enable_authorization false
  end

  factory :kallidus_learn_integration_inventory, parent: :integration_inventory do
    display_name 'Learn'
    status 2
    category 7
    data_direction 0
    enable_filters true
    api_identifier 'kallidus_learn'
    enable_authorization false
  end

  factory :team_spirit_integration_inventory, parent: :integration_inventory do
    display_name 'TeamSpirit'
    status 2
    category 1
    data_direction 0
    enable_filters true
    api_identifier 'team_spirit'
    enable_authorization false
  end

  factory :service_now_integration_inventory, parent: :integration_inventory do
    display_name 'ServiceNow'
    status 2
    category 1
    data_direction 0
    enable_filters true
    api_identifier 'service_now'
    enable_authorization false
  end

  factory :bswift_integration_inventory, parent: :integration_inventory do
    display_name 'BSwift'
    status 2
    category 1
    data_direction 0
    enable_filters true
    api_identifier 'bswift'
    enable_authorization false
    end

  factory :workday_integration_inventory, parent: :integration_inventory do
    display_name { 'Workday' }
    status { 2 }
    category { 1 }
    data_direction { 0 }
    enable_filters { true }
    api_identifier { 'workday' }
    enable_authorization { false }
  end

  factory :smartrecruiters_integration_inventory, parent: :integration_inventory do
    display_name { 'SmartRecruiters' }
    status { 2 }
    category { 1 }
    data_direction { 0 }
    enable_filters { true }
    api_identifier { 'smart_recruiters' }
    enable_authorization { false }
  end

  factory :jazzhr_integration_inventory, parent: :integration_inventory do
    display_name 'JazzHR'
    status 2
    category 0
    data_direction 1
    enable_filters false
    api_identifier 'jazz_hr'
    enable_authorization false
  end

  factory :workable_integration_inventory, parent: :integration_inventory do
    display_name 'Workable'
    status 2
    category 0
    data_direction 1
    enable_filters false
    api_identifier 'workable'
    enable_authorization false
  end

  factory :asana_integration_inventory, parent: :integration_inventory do
    display_name { 'Asana' }
    status { 2 }
    category { 2 }
    data_direction { 0 }
    enable_filters { false }
    api_identifier { 'asana' }
    enable_authorization { false }
  end

  factory :xero_integration_inventory, parent: :integration_inventory do
    display_name { 'Xero' }
    status { 2 }
    category { 2 }
    data_direction { 0 }
    enable_filters { false }
    api_identifier { 'xero' }
    enable_authorization { false }
  end

  factory :google_sso_integration_inventory, parent: :integration_inventory do
    display_name 'Google_SSO'
    status 2
    category 3
    data_direction 0
    enable_filters false
    api_identifier 'google_auth'
    enable_authorization false
  end

  factory :one_login_integration_inventory, parent: :integration_inventory do
    display_name 'one login'
    status 2
    category 3
    data_direction 0
    enable_filters false
    api_identifier 'one_login'
    enable_authorization false
  end

  factory :okta_integration_inventory, parent: :integration_inventory do
    display_name 'Okta'
    status 2
    category 3
    data_direction 0
    enable_filters false
    api_identifier 'okta'
    enable_authorization false
  end

  factory :ADFS_integration_inventory, parent: :integration_inventory do
    display_name 'ADFS'
    status 2
    category 3
    data_direction 0
    enable_filters false
    api_identifier 'active_directory_federation_services'
    enable_authorization false
  end

  factory :shibboleth_integration_inventory, parent: :integration_inventory do
    display_name 'Shibboleth'
    status 2
    category 3
    data_direction 0
    enable_filters false
    api_identifier 'shibboleth'
    enable_authorization false
  end

  factory :ping_id_integration_inventory, parent: :integration_inventory do
    display_name 'Ping ID'
    status 2
    category 3
    data_direction 0
    enable_filters false
    api_identifier 'ping_id'
    enable_authorization false
  end

  factory :adfs_productivity_integration_inventory, parent: :integration_inventory do
    display_name 'adfs_productivity'
    status 2
    category 2
    data_direction 0
    enable_filters false
    api_identifier 'adfs_productivity'
    enable_authorization true
  end

  factory :gsuite_integration_inventory, parent: :integration_inventory do
    display_name 'Gsuite'
    status 2
    category 2
    data_direction 0
    enable_filters false
    api_identifier 'gsuite'
    enable_authorization true
  end

  factory :slack_communication_integration_inventory, parent: :integration_inventory do
    display_name 'Slack Communication'
    status 2
    category 2
    data_direction 0
    enable_filters false
    api_identifier 'slack_communication'
  end
end
