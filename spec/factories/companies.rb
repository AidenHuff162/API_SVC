FactoryGirl.define do
  factory :company do
    name { Faker::Company.name }
    abbreviation { Faker::Hipster.word }
    brand_color { Faker::Color.hex_color }
    bio { Faker::Hipster.paragraph }
    is_using_custom_table true
    notifications_enabled { true }
    sequence :email do |n|
      "email#{n}"
    end
    subdomain { Faker::Hipster.word + Time.now.to_i.to_s}

    after(:create) do |company|
      create(:onboarding_profile_template, company: company, process_type: company.process_types.find_by(name: "Onboarding"), name: "US Profile Template")
      create(:offboarding_profile_template, company: company, process_type: company.process_types.find_by(name: "Offboarding"), name: "Offboarding Profile Template")
    end

    factory :company_with_history do
      after(:create) do |company|
        create(:history, company: company)
      end
    end
    factory :company_with_user do
      after(:create) do |company|
        create(:sarah, company: company)
      end
    end

    factory :company_with_team_and_location do
      after(:create) do |company|
        create(:team, company: company, name: 'Marketing')
        create(:team, company: company, name: 'Sales')
        create(:location, company: company, name: 'London')
        create(:location, company: company, name: 'New York')
        create(:location, company: company, name: 'Turkey')
      end
    end

    factory :addepar_company do
      initialize_with do
        c = Company.with_deleted.find_by(id: 34)
        c.restore(recursive: true)  if c.present? && c.deleted_at
        c = c.nil? ? FactoryGirl.build(:company, id: 34) : c
      end
    end
    factory :five_company do
      initialize_with do
        c = Company.with_deleted.find_by(id: 64)
        c.restore(recursive: true)  if c.present? && c.deleted_at
        c = c.nil? ? FactoryGirl.build(:company, id: 64) : c
      end
    end

    factory :door_company do
      initialize_with do
        c = Company.with_deleted.find_by(id: 185)
        c.restore(recursive: true)  if c.present? && c.deleted_at
        c = c.nil? ? FactoryGirl.build(:company, id: 185) : c
      end
    end

    factory :digital_company do
      initialize_with do
        c = Company.with_deleted.find_by(id: 20)
        c.restore(recursive: true)  if c.present? && c.deleted_at
        c = c.nil? ? FactoryGirl.build(:company, id: 20) : c
      end
    end

    factory :forward_company do
      initialize_with do
        c = Company.with_deleted.find_by(id: 288)
        c.restore(recursive: true)  if c.present? && c.deleted_at
        c = c.nil? ? FactoryGirl.build(:company, id: 288) : c
      end
    end

    factory :zapier_company do
      initialize_with do
        c = Company.with_deleted.find_by(id: 191)
        c.restore(recursive: true)  if c.present? && c.deleted_at
        c = c.nil? ? FactoryGirl.build(:company, id: 191) : c
      end
    end

    factory :scality_company do
      initialize_with do
        c = Company.with_deleted.find_by(id: 32)
        c.restore(recursive: true)  if c.present? && c.deleted_at
        c = c.nil? ? FactoryGirl.build(:company, id: 32) : c
      end
    end
  end


  factory :company_with_operation_contact, parent: :company  do
    after(:create) do |company|
      peter = create(:peter, company: company)
      company.operation_contact_id = peter.id
      company.save!
    end
  end

  factory :gsuite_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company ,api_name: "gsuite" ,gsuite_account_url: Faker::Internet.url('example.com') , is_enabled: true , secret_token: "thisIsAdummySecretTokenthisIsAdummySecretTokenthisIsAdummySecretToken")
    end
  end

  factory :rocketship_company, parent: :company do
    name 'Rocketship'
    subdomain 'rocketship'
    email 'rocketship'
    brand_color '#2A57A0'
    abbreviation 'Rocketship'
    display_logo_image { build(:display_logo_image, :for_rocketship) }
    is_using_custom_table true
    bio 'Rocketship Software Incorporated designs, manufactures'\
      'and launches advanced rockets and spacecraft. The company '\
      'was founded in 2002 to revolutionize space technology, '\
      'with the ultimate goal of enabling people to live '\
      'on other planets.'\
      'Rocketship has 100 employees across five locations '\
      '(San Francisco (HQ), New York, Chicago, Hong Kong and '\
      'London) in five teams (Sales, Marketing, Operations, '\
      'Product and Engineering).'
  end

  factory :company_with_random_users, parent: :company do
    after(:create) do |company|
      london = create(:location, company: company, name: 'London')
      san_fransisco = create(:location, company: company, name: 'San Fransisco')
      new_york = create(:location, company: company, name: 'New York')

      create(:departed_user_with_no_gdpr, company: company, location: london)
      create(:departed_user_with_no_gdpr, company: company, location: san_fransisco)
      create(:departed_user_with_no_gdpr, company: company, location: new_york)
      create(:departed_user_with_no_gdpr, company: company, location: nil)

      create(:departed_user_with_gdpr, company: company, location: london)
      create(:departed_user_with_gdpr, company: company, location: san_fransisco)
      create(:departed_user_with_gdpr, company: company, location: new_york)
      create(:departed_user_with_gdpr, company: company, location: nil)

      create(:user_with_location, company: company, location: london)
      create(:user_with_location, company: company, location: san_fransisco)
      create(:user_with_location, company: company, location: new_york)
      create(:user_with_location, company: company, location: nil)

      create(:offboarding_user, company: company, location: london)
      create(:offboarding_user, company: company, location: san_fransisco)
      create(:offboarding_user, company: company, location: new_york)
      create(:offboarding_user, company: company, location: nil)
    end
  end

  factory :with_namely_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company, api_name: "namely")
    end
  end

  factory :with_bamboo_integration, parent: :company do
    after(:create) do |company|
      create(:bamboohr_integration, company: company)
    end
  end

  factory :with_bamboo_adp_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company, api_name: "adp_wfn_profile_creation_and_bamboo_two_way_sync")
    end
  end

  factory :with_adp_us_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company, api_name: 'adp_wfn_us')
    end
  end

  factory :with_adp_can_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company, api_name: 'adp_wfn_can')
    end
  end

  factory :with_adp_us_and_can_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company, api_name: 'adp_wfn_can')
      create(:integration, company: company, api_name: 'adp_wfn_us')
    end
  end

  factory :with_paylocity_integration, parent: :company do
    after(:create) do |company|
      create(:paylocity, company: company)
    end
  end

  factory :with_paylocity_and_paylocity_integration_type, parent: :with_paylocity_integration do
    after(:create) do |company|
      company.update(paylocity_integration_type: 'onboarding_webpay')
    end
  end

  factory :with_fifteen_five_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company, api_name: "fifteen_five")
    end
  end

  factory :with_peakon_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company, api_name: "peakon")
    end
  end

  factory :with_workday_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company, api_name: "workday")
    end
  end

  factory :with_bswift_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company, api_name: "bswift", is_enabled: true)
    end
  end

  factory :handshake_company, parent: :company do
    initialize_with do
      c = Company.with_deleted.find_by(id: 195)
      c.restore(recursive: true)  if c.present? && c.deleted_at
      c = c.nil? ? FactoryGirl.build(:company, id: 195) : c
    end
  end

  factory :hellosign_company, parent: :company do
    initialize_with do
      c = Company.with_deleted.find_by(id: 90)
      c.restore(recursive: true)  if c.present? && c.deleted_at
      c = c.nil? ? FactoryGirl.build(:company, id: 90) : c
    end
  end

  factory :with_linkedin_integration, parent: :company do
    after(:create) do |company|
      create(:integration, company: company, api_name: "linked_in", is_enabled: true)
    end
  end
end
