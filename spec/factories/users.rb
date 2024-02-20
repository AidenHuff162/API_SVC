FactoryGirl.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    preferred_name { Faker::Name.last_name }
    start_date { 10.days.from_now.to_date }
    email { Faker::Internet.email }
    title { Faker::Name.title }
    personal_email { Faker::Internet.email }
    password { 'secret123$' }
    state :active
    role :account_owner
    deleted_at { }
    current_stage :preboarding
    updated_by_admin true # this is added to avoid running field history creation callback every time
    trait :run_field_history_callback do
      updated_by_admin false
    end
    factory :user_with_profile do
      after(:create) do |user|
        create(:profile, user: user)
      end
    end

    factory :user_with_deleted_policies do
      after(:create) do |user|
        policy = create(:default_pto_policy, company: user.company)
        3.times do |count|
          create(:assigned_pto_policy, user_id: user.id, pto_policy_id: policy.id, deleted_at: Time.now)
        end
      end
    end

    factory :assigned_policy_having_no_pto_policy do
      after(:create) do |user|
        policy = create(:default_pto_policy, company: user.company)
        create(:assigned_pto_policy, user_id: user.id, pto_policy_id: policy.id, deleted_at: Time.now)
        policy.update_column(:deleted_at, Time.now)
      end
    end

    factory :user_with_tasks do
      after(:create) do |user|
        workstream = FactoryGirl.create(:workstream_with_tasks)
        create(:task_user_connection, user: user, task: workstream.tasks.first)
        user.fix_counters
      end
    end

    factory :user_with_location do
      location
    end

    trait :manager do
      after(:create) do |user|
        create(:user, company: user.company)
      end
    end
    trait :with_calendar_feed do
      after(:create) do |user|
        create(:calendar_feed, company: user.company, user: user)
      end
    end
    company
  end

  factory :nick, parent: :user do
    first_name 'Nick'
    last_name 'Newton'
    email 'nick@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'nick.personal@test.com'
    title 'Operations Analyst'
    role :employee
    state :active
    current_stage :invited
    profile_image { build(:profile_image, :for_nick) }
    trait :with_special_character_in_email do
      email 'ni-ck@test.com'
    end
    trait :with_view_edit_time_off_platform_visbility do
      after(:create) do |user|
        role = user.user_role
        role.permissions["platform_visibility"]["time_off"] = 'view_and_edit'
        user.company.update_column(:enabled_time_off, true)
        role.save
      end
    end

    manager {build(:user, role: :employee, company: self.company)}
    trait :manager_with_role do
      after(:create) do |user|
        role = FactoryGirl.create(:manager)
        user.manager.update(user_role_id: role.id)
      end
    end

    trait :with_location do
      location
    end
  end

  factory :user_manual_assigned_policy_factory, parent: :nick do
    after(:create) do |user|
      policy = create(:default_pto_policy, company: user.company, allocate_accruals_at: 0, accrual_frequency: 0, for_all_employees: false)
      user.pto_policies << policy
      user.assigned_pto_policies.first.update(manually_assigned: true)
    end
    trait :not_assigned_manually do
      after(:create) do |user|
        user.assigned_pto_policies.first.update(manually_assigned: false)
      end
    end
  end

  factory :user_with_pto_policy_for_some_employees_factory, parent: :nick do
    after(:create) do |user|
      policy = create(:default_pto_policy, company: user.company, allocate_accruals_at: 0, accrual_frequency: 0, for_all_employees: false)
      user.pto_policies << policy
    end
  end

  factory :user_with_field_history, parent: :nick do
    trait :profile_field_history do
      after(:create) do |user|
        field_history = create(:field_history, field_name: 'About You', field_changer: user, field_type: 6, field_auditable_type: 'Profile', field_auditable_id: user.profile.id, new_value: 'hello')
      end
    end
  end

  factory :user_with_manager_and_policy, parent: :nick do
    manager {build(:user, company: self.company)}
    after(:create) do |user|
      policy = create(:default_pto_policy, company: user.company, allocate_accruals_at: 0, accrual_frequency: 0)
      user.pto_policies << policy
    end
    trait :auto_approval do
      after(:create) do |user|
        user.pto_policies.first.update(manager_approval: false)
      end
    end

    trait :manually_assigned do
      after(:create) do |user|
        user.assigned_pto_policies.first.update(manually_assigned: true)
      end
    end

    trait :cannot_obtain_negative_balance do
      after(:create) do |user|
        user.pto_policies.first.update(can_obtain_negative_balance: false)
      end
    end

    trait :wih_max_accrual do
      after(:create) do |user|
        user.pto_policies.first.update(has_max_accrual_amount: true, max_accrual_amount: 3)
      end
    end

    trait :with_policies_accrual_at_end_of_period do
      after(:create) do |user|
        user.pto_policies.first.update(allocate_accruals_at: 1)
      end
    end

    trait :daily_policy do
      after(:create) do |user|
        user.pto_policies.first.update(accrual_frequency: 0)
      end
    end

    trait :renewal_on_anniversary do
      after(:create) do |user|
        user.pto_policies.first.update(accrual_renewal_time: 'anniversary_date')
      end
    end

    trait :super_admin do
      after(:create) do |user|
        user.update(user_role_id: user.company.user_roles.where(role_type: 3).first.id)
      end
    end

    trait :unlimited_policy do
      after(:create) do |user|
        user.pto_policies.first.update(unlimited_policy: true)
      end
    end

    trait :with_maximum_increment do
      after(:create) do |user|
        user.pto_policies.first.update(has_maximum_increment: true, maximum_increment_amount: 8)
      end
    end

    trait :with_minimum_increment do
      after(:create) do |user|
        user.pto_policies.first.update(has_minimum_increment: true, minimum_increment_amount: 8)
      end
    end

    trait :with_expiry_and_renewal_today do
      after(:create) do |user|
        user.pto_policies.first.update_columns(expire_unused_carryover_balance: true, carryover_amount_expiry_date: user.company.time - 1.day, accrual_renewal_time: 2, accrual_renewal_date: user.company.time)
      end
    end

  end

  factory :user_with_disabled_manually_assigned_pto_policy, parent: :user do
    after(:create) do |user|
      team = create(:team)
      location = create(:location)
      policy = create(:default_pto_policy, company: user.company, for_all_employees: false, filter_policy_by: {"teams": [team.id], "location": [location.id], "employee_status": ["all"]}, is_enabled: false)
      AssignedPtoPolicy.create(user_id: user.id, pto_policy_id: policy.id, deleted_at: Date.today, manually_assigned: true)
    end
  end

  factory :user_with_deleted_assigned_pto_policy, parent: :nick do
    after(:create) do |user|
      policy = create(:default_pto_policy ,:policy_for_some_employees, company: user.company)
      AssignedPtoPolicy.create({user_id: user.id, pto_policy_id: policy.id, deleted_at: Date.today})
    end
    location
    team
  end

  factory :tim, parent: :user do
    first_name 'Tim'
    last_name 'Taylor'
    email 'tim@test.com'
    preferred_name { Faker::Name.last_name }
    password ENV['USER_PASSWORD']
    personal_email 'tim.personal@test.com'
    title 'Engineering Manager'
    start_date {10.days.ago }
    role :employee
    state :active
    current_stage :pre_start
    profile_image { build(:profile_image, :for_tim) }

    trait :with_location do
      location
    end
  end

  factory :peter, parent: :user do
    first_name 'Peter'
    last_name 'Parker'
    email 'peter@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'peter.personal@test.com'
    title 'Operations Manager'
    role :admin
    state :active
    current_stage :pre_start
    profile_image { build(:profile_image, :for_peter) }

    trait :with_location_and_team do
      location
      team
    end
  end


  factory :test1, parent: :user do
    first_name 'Test1'
    last_name 'TLast1'
    email 'test1@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'test.personal@test.com'
    title 'Operations Manager'
    role :admin
    state :active
    current_stage :pre_start
    profile_image { build(:profile_image, :for_peter) }

    trait :with_location_and_team do
      location
      team
    end
  end

  factory :taylor, parent: :user do
    first_name 'Taylor'
    last_name 'Lockwood'
    email 'taylor@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'taylor.personal@test.com'
    title 'Operations Manager'
    role :admin
    state :active
    current_stage :invited
    profile_image { build(:profile_image, :for_peter) }

    trait :with_location do
      after(:create) do |user|
        create(:location, name: 'Paris', company: user.company, owner: user)
      end
    end
  end

  factory :sarah, parent: :user do
    first_name 'Sarah'
    last_name 'Salem'
    email 'sarah@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'sarah.personal@test.com'
    title 'Head of Operations'
    role :account_owner
    state :active
    current_stage :registered
    profile_image { build(:profile_image, :for_sarah) }
    seen_profile_setup true
    onboarding_profile_template_id :nil

    trait :with_location_and_team do
      location
      team
    end
  end

  factory :maria, parent: :user do
    first_name 'Maria'
    last_name 'Salem'
    email 'maria@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'maria.personal@test.com'
    title 'Head of Operations'
    role :account_owner
    state :active
    current_stage :registered
    profile_image { build(:profile_image, :for_sarah) }

    trait :with_location do
      after(:create) do |user|
        create(:location, name: 'London', company: user.company, owner: user)
      end
    end
  end

  factory :addys, parent: :user do
    first_name 'Addys'
    last_name 'Ada'
    email 'addys.company@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'addys.personal@test.com'
    title 'Engineering Manager'
    start_date { 40.days.ago }
    role :employee
    state :active
    current_stage :ramping_up

    trait :with_location_and_team do
      location
      team
    end

    trait :workstream_with_tasks
      after(:create) do |user|
        workstream = FactoryGirl.create(:workstream_with_tasks)
        create(:task_user_connection, user: user, task: workstream.tasks.first)
        user.fix_counters
      end
  end

  factory :agatha, parent: :user do
    first_name 'Agatha'
    last_name 'Alton'
    email 'agatha.company@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'agatha.personal@test.com'
    title 'Engineering Manager'
    start_date {5.days.ago }
    role :employee
    state :active
    current_stage :first_week

    trait :with_location_and_team do
      location
      team
    end
  end

  factory :hilda, parent: :user do
    first_name 'Hilda'
    last_name 'Hester'
    email 'hilda.company@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'hilda.personal@test.com'
    title 'Engineering Manager'
    start_date { 10.days.ago }
    role :account_owner
    state :active
    current_stage :first_month

    trait :with_location_and_team do
      location
      team
    end
  end

  factory :zebediah, parent: :user do
    first_name 'Zebediah'
    last_name 'Zane'
    email 'zebediah.@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'zebediah.personal@test.com'
    title 'Engineering Manager'
    start_date { 40.days.ago }
    role :employee
    state :active
    current_stage :registered

    trait :with_location_and_team do
      location
      team
    end
  end

  factory :williams, parent: :user do
    first_name 'Williams'
    last_name 'Lam'
    email 'williams.@test.com'
    password ENV['USER_PASSWORD']
    personal_email 'williams.personal@test.com'
    title 'Engineering Manager'
    start_date { 10.days.ago }
    role :employee
    state :active
    current_stage :preboarding

    trait :with_location do
      after(:create) do |user|
        create(:location, name: 'London', company: user.company, owner: user)
      end
    end
  end

  factory :departed_user_with_no_gdpr, parent: :user do
    current_stage :departed
    is_gdpr_action_taken false
    gdpr_action_date nil
    termination_date { Date.yesterday-20.days }
    state :inactive

    location
  end

  factory :departed_user_with_gdpr, parent: :user do
    current_stage :departed
    is_gdpr_action_taken true
    gdpr_action_date { Date.yesterday-8.years }
    termination_date { Date.yesterday-8.years }
    state :inactive

    location
  end

  factory :offboarding_user, parent: :user do
    current_stage :last_month
    is_gdpr_action_taken false
    gdpr_action_date nil
    termination_date { Date.today+10.days }
    state :inactive

    location
  end

  factory :user_with_standard_custom_table, parent: :user do
    after(:create) do |user|
      create(:standarad_custom_table_with_phone_currency_and_text_field_with_value, table_type: :standard, name: 'standard table', user: user, company: user.company)
    end
  end

  factory :user_with_timeline_custom_table, parent: :user do
    after(:create) do |user|
      create(:timeline_custom_table_with_phone_currency_and_text_field_with_value, table_type: :timeline, name: 'timeline table', user: user, company: user.company)
    end
  end

  factory :offboarded_user, parent: :user do
    start_date { 10.days.ago }
    termination_date { 2.days.ago }
    last_day_worked { 2.days.ago }
    termination_type :voluntary
    eligible_for_rehire :yes
    current_stage :departed

    trait :user_with_past_snapshot do
      after(:create) do |user|
        create(:custom_table_user_snapshot, user_id: user.id, effective_date: 5.days.ago, is_terminated: false, custom_table: CustomTable.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]))
      end
    end
    trait :user_with_terminated_snapshot do
      after(:create) do |user|
        create(:employement_status_snapshot_with_effective_date, terminate_job_execution: true, custom_table: CustomTable.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]), user: user, terminated_data: {last_day_worked: user.last_day_worked})
      end
    end

    trait :user_with_current_date_snapshot do
      after(:create) do |user|
        create(:custom_table_user_snapshot, user_id: user.id, effective_date: Time.now.in_time_zone(user.company.time_zone).to_date, is_terminated: false, custom_table: CustomTable.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]))
      end
    end

    trait :user_with_future_snapshot do
      after(:create) do |user|
        create(:custom_table_user_snapshot, user_id: user.id, effective_date: 5.days.ago, custom_table: CustomTable.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information]))
        create(:custom_table_user_snapshot, user_id: user.id, effective_date: 10.days.from_now, state: CustomTableUserSnapshot.states[:queue], custom_table: CustomTable.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information]))
      end
    end

    trait :user_with_timeline_custom_table do
      after(:create) do |user|
        create(:timeline_custom_table_with_phone_currency_and_text_offboarding_field, table_type: :timeline, name: 'timeline table', user: user, company: user.company)
      end
    end
  end

  factory :user_with_manager_form_field, parent: :user do
    after(:create) do |user|
      create(:timeline_custom_table_with_phone_currency_and_text_manager_field, table_type: :timeline, name: 'timeline table', user: user, company: user.company)
    end
  end

  factory :with_manager_form_custom_snapshots, parent: :user_with_manager_form_field do
    after(:create) do |user|
      create(:custom_table_user_snapshot, user: user, effective_date: user.start_date.strftime("%B %d, %Y"), custom_table: user.company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:general], table_type: CustomTable.table_types[:timeline]))
    end
  end

  factory :rehire_user, parent: :user do
    start_date { 10.days.from_now.to_date }
    termination_date nil
    last_day_worked nil
    termination_type nil
    eligible_for_rehire nil
    current_stage :invited

    trait :user_with_past_snapshot do
      after(:create) do |user|
        create(:custom_table_user_snapshot, user_id: user.id, effective_date: 5.days.ago, is_terminated: true, custom_table: CustomTable.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]))
      end
    end
  end

  factory :user_with_past_snapshot, parent: :user do
    after(:create) do |user|
      create(:custom_table_user_snapshot, user_id: user.id, effective_date: 5.days.ago, is_terminated: true, custom_table: CustomTable.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]))
    end
  end
end
