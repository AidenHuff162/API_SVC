FactoryGirl.define do
	factory :custom_field do
		name {Faker::Company.name}
		section {Faker::Number.between(0, 4)}
    position  { 0 }
    required_existing { true }

    trait :ssn_field do
    field_type 5
    end

    trait :date_of_birth do
      name 'Date of Birth'
      skip_validations true
    end

    trait :employee_number do
      name 'Employee Number'
      field_type 10
    end

    trait :user_info_and_profile_custom_field do
      name 'Dream Vacation Spot'
      section { Faker::Number.between(0, 2) }
      skip_validations true
    end

    trait :gender_field do
      name 'Gender'
      field_type 2
    end

    trait :with_sub_custom_fields do
      sub_custom_fields { build_list :sub_custom_field, 3 }
    end

    trait :home_address do
      field_type 7
    end

    factory :address_with_multiple_sub_custom_fields do
      name 'Home Address'
      field_type 7
      skip_validations true
      after(:create) do |custom_field|
        custom_field.sub_custom_fields << create(:sub_custom_field, name: 'Line 1', field_type: 0, help_text: 'Line 1')
        custom_field.sub_custom_fields << create(:sub_custom_field, name: 'Line 2', field_type: 0, help_text: 'Line 2')
        custom_field.sub_custom_fields << create(:sub_custom_field, name: 'City', field_type: 0, help_text: 'City')
        custom_field.sub_custom_fields << create(:sub_custom_field, name: 'Country', field_type: 0, help_text: 'Country')
        custom_field.sub_custom_fields << create(:sub_custom_field, name: 'State', field_type: 0, help_text: 'State')
        custom_field.sub_custom_fields << create(:sub_custom_field, name: 'Zip', field_type: 0, help_text: 'Zip / Postal Code')
      end
    end

		factory :custom_field_with_value do
			after(:create) do |custom_field|
				create(:custom_field_value, custom_field: custom_field)
			end
		end

    factory :custom_field_with_value_and_user do
      after(:create) do |custom_field|
        user = create(:user)
        create(:custom_field_value, custom_field: custom_field, user: user)
      end
    end

    factory :custom_field_with_task do
      after(:create) do |custom_field|
        create(:task, custom_field: custom_field)
      end
    end

    factory :workday_gender, parent: :custom_field  do
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Male', workday_wid: '1')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Female', workday_wid: '2')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Not specified', workday_wid: '3')
      end
    end

    factory :custom_table_custom_field, parent: :custom_field do
      custom_table
    end

    factory :workday_federal_marital_status, parent: :custom_field  do
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Married', workday_wid: '1')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Single', workday_wid: '2')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Divorced', workday_wid: '3')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Partnered', workday_wid: '4')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Separated', workday_wid: '5')
      end
    end

    factory :workday_citizenship_type, parent: :custom_field do
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Citizen', workday_wid: '1')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Naturalized Citizen', workday_wid: '2')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Permanent Resident', workday_wid: '3')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Temporary Resident', workday_wid: '4')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Visitor', workday_wid: '5')
      end
    end

    factory :workday_citizenship_country, parent: :custom_field do
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'USA', workday_wid: '6')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'UK', workday_wid: '7')
      end
    end

    factory :workday_military_service, parent: :custom_field do
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Active', workday_wid: '1')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Inactive', workday_wid: '2')
      end
    end

    factory :workday_disability, parent: :custom_field do
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Speech Impairment', workday_wid: '1')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Learning Impairment', workday_wid: '2')
      end
    end

    factory :workday_ethnicity, parent: :custom_field do
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Asian', workday_wid: '1')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'White', workday_wid: '2')
      end
    end

    factory :workday_pronoun, parent: :custom_field do
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Prof', workday_wid: '1')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Miss', workday_wid: '2')
      end
    end

    factory :workday_termination_reason, parent: :custom_field do
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Voluntary', workday_wid: '1')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Involuntary', workday_wid: '2')
      end
    end

    factory :workday_phone_number, parent: :custom_field do
      field_type 8
      after(:create) do |custom_field|
        custom_field.sub_custom_fields << FactoryGirl.create(:sub_custom_field, name: 'Country', field_type: 'short_text')
        custom_field.sub_custom_fields << FactoryGirl.create(:sub_custom_field, name: 'Area code', field_type: 'short_text')
        custom_field.sub_custom_fields << FactoryGirl.create(:sub_custom_field, name: 'Phone', field_type: 'short_text')
      end
    end

    factory :calculation_type, parent: :custom_field do
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'user earning rate')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'enter earning rate')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'annual salary')
     end
    end

    factory :xero_employment_status, parent: :custom_field do
      field_type 13
      after(:create) do |custom_field|
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Full Time')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Part Time')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Casual')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Labour Hire')
        custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'super in come stream')
     end
    end
	end

  factory :mobile_phone_number_field, parent: :custom_field do
    name 'Mobile Phone Number'
    section 'private_info'
    field_type 8
    required false
    position 2
    skip_validations true
    after(:create) do |custom_field|
      custom_field.sub_custom_fields << FactoryGirl.create(:sub_custom_field, name: 'Country', field_type: 'short_text')
      custom_field.sub_custom_fields << FactoryGirl.create(:sub_custom_field, name: 'Area code', field_type: 'short_text')
      custom_field.sub_custom_fields << FactoryGirl.create(:sub_custom_field, name: 'Phone', field_type: 'short_text')
    end
  end

  factory :workday_emergency_contact_relationship, parent: :custom_field do
    after(:create) do |custom_field|
      custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Wife', workday_wid: '1')
      custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Husband', workday_wid: '2')
    end
  end

  factory :phone_field, parent: :custom_field do
    transient do
      user { nil }
    end
    name 'International Phone Number'
    section nil
    field_type 8
    required false
    after(:create) do |custom_field, object|
      create(:country_code_sub_custom_field, custom_field: custom_field, name: 'Country', field_type: 'short_text', user: object.user)
      create(:area_code_sub_custom_field, custom_field: custom_field, name: 'Area code', field_type: 'short_text', user: object.user)
      create(:phone_sub_custom_field, custom_field: custom_field, name: 'Phone', field_type: 'short_text', user: object.user)
    end
  end

  factory :currency_field, parent: :custom_field do
    transient do
      user { nil }
    end
    name 'Salary'
    section nil
    field_type 14
    required false
    after(:create) do |custom_field, object|
      create(:currency_code_sub_custom_field, custom_field: custom_field, name: 'Currency Type', field_type: 'short_text', user: object.user)
      create(:currency_value_sub_custom_field, custom_field: custom_field, name: 'Currency Value', field_type: 'number', user: object.user)
    end
  end

  factory :currency_field_with_value, parent: :custom_field do
    transient do
      user { nil }
    end
    name 'Salary'
    section nil
    field_type 14
    required false
    after(:create) do |custom_field, object|
      create(:currency_code_sub_custom_field, :with_value, custom_field: custom_field, name: 'Currency Type', field_type: 'short_text', user: object.user)
      create(:currency_value_sub_custom_field, :with_value, custom_field: custom_field, name: 'Currency Value', field_type: 'number', user: object.user)
    end
  end

  factory :phone_field_with_value, parent: :custom_field do
    transient do
      user { nil }
    end
    name 'International Phone Number'
    section nil
    field_type 8
    required false
    after(:create) do |custom_field, object|
      custom_field.sub_custom_fields << FactoryGirl.create(:country_code_sub_custom_field, :with_value, name: 'Country', field_type: 'short_text', user: object.user)
      custom_field.sub_custom_fields << FactoryGirl.create(:area_code_sub_custom_field, :with_value, name: 'Area code', field_type: 'short_text', user: object.user)
      custom_field.sub_custom_fields << FactoryGirl.create(:phone_sub_custom_field, :with_value, name: 'Phone', field_type: 'short_text', user: object.user)
    end
  end

  factory :sin_field_with_value, parent: :custom_field do
    transient do
      user { nil }
    end
    name 'Social Insurance Number'
    section nil
    field_type CustomField.field_types[:social_insurance_number]
    required false
  end

  factory :text_field, parent: :custom_field do
    transient do
      user { nil }
    end
    name 'short text field'
    section nil
    field_type 0
    required false
    trait :with_value do
      after(:create) do |custom_field, object|
        create(:custom_field_value, custom_field: custom_field, value_text: 'this is short text', user: object.user)
      end
    end
  end

  factory :currency_field_with_snapshot, parent: :custom_field do
    transient do
      custom_table_user_snapshots { nil }
    end
    name 'Salary'
    section nil
    field_type 14
    required false
    after(:create) do |custom_field, object|
      create(:custom_snapshot, custom_field_id: custom_field.id, custom_table_user_snapshot_id: object.custom_table_user_snapshots.id, custom_field_value: 'USD|200')
    end
  end

  factory :phone_field_with_snapshot, parent: :custom_field do
    transient do
      custom_table_user_snapshots { nil }
    end
    name 'International Phone Number'
    section nil
    field_type 8
    required false
    after(:create) do |custom_field, object|
      create(:custom_snapshot, custom_field_id: custom_field.id, custom_table_user_snapshot_id: object.custom_table_user_snapshots.id, custom_field_value: 'PAK|92|1111111')
    end
  end

  factory :text_field_with_snapshot, parent: :custom_field do
    transient do
      custom_table_user_snapshots { nil }
    end
    name 'short text field'
    section nil
    field_type 0
    required false
    trait :with_value do
      after(:create) do |custom_field, object|
        create(:custom_snapshot, custom_field_id: custom_field.id, custom_table_user_snapshot_id: object.custom_table_user_snapshots.id, custom_field_value: 'ok')
      end
    end
  end

  factory :custom_group, parent: :custom_field do
    name 'Custom Group'
    section nil
    field_type CustomField.field_types['mcq']
    required false
    after(:create) do |custom_field, object|
      custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Male')
      custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Female')
    end
  end

  factory :adp_rate_type_with_value, parent: :custom_field do
    field_type 4
    transient do
      user { nil }
    end
    name 'Rate Type'
    after(:create) do |custom_field, object|
      custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'user earning rate', adp_wfn_us_code_value: 'UER')
      custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'enter earning rate', adp_wfn_us_code_value: 'EER')
      custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'annual salary', adp_wfn_us_code_value: 'AS')
      create(:custom_field_value, custom_field: custom_field, custom_field_option_id: custom_field.custom_field_options.last.id, user: object.user)
    end
  end

  factory :adp_race_ethnicity, parent: :custom_field do
    field_type 4
    transient do
      user { nil }
    end
    name 'Race/Ethnicity'
    after(:create) do |custom_field, object|
      custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Hispanic or Latino', adp_wfn_us_code_value: '2')
      custom_field.custom_field_options << FactoryGirl.create(:custom_field_option, option: 'Black or African American', adp_wfn_us_code_value: '1')
      create(:custom_field_value, custom_field: custom_field, custom_field_option_id: custom_field.custom_field_options.last.id, user: object.user)
    end
  end

end
