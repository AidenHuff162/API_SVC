FactoryGirl.define do
  factory :custom_table do
  	name 'Sample Custom Table'
  	table_type CustomTable.table_types[:timeline]
  	custom_table_property CustomTable.custom_table_properties[:general]
  	is_approval_required false
  	approval_type nil
  	approval_ids []
  	approval_expiry_time nil

  	company
  end

  factory :approval_custom_table_with_requested_custom_table_user_snapshots, parent: :custom_table do
    after(:create) do |custom_table|
      create(:custom_table_user_snapshot, user: create(:user, company: custom_table.company), custom_table: custom_table, state: CustomTableUserSnapshot.states[:applied], request_state: CustomTableUserSnapshot.request_states[:requested])
    end
    company
  end

  factory :non_approval_custom_table_with_custom_table_user_snapshots, parent: :custom_table do
    after(:create) do |custom_table|
      create(:custom_table_user_snapshot, user: create(:user, company: custom_table.company), custom_table: custom_table, state: CustomTableUserSnapshot.states[:applied], request_state: nil, effective_date: Date.today)
    end
    company
  end

  factory :general_table_with_text_field, parent: :custom_table do
    after(:create) do |custom_table|
      create(:custom_field, custom_table: custom_table, company: custom_table.company)
   end
  end 

  factory :standarad_custom_table_with_phone_currency_and_text_field_with_value, parent: :custom_table do
    transient do
      user { nil }
    end
    after(:create) do |custom_table, object|
      create(:currency_field_with_value, custom_table: custom_table, company: custom_table.company, user: object.user)
      create(:phone_field_with_value, custom_table: custom_table, company: custom_table.company, user: object.user)
      create(:text_field, :with_value, custom_table: custom_table, company: custom_table.company, user: object.user)
    end
  end

  factory :timeline_custom_table_with_phone_currency_and_text_field_with_value, parent: :custom_table do
    transient do
      user { nil }
    end
    after(:create) do |custom_table, object|
      create(:currency_field_with_value, custom_table: custom_table, company: custom_table.company, user: object.user)
      create(:phone_field_with_value, custom_table: custom_table, company: custom_table.company, user: object.user)
      create(:text_field, :with_value, custom_table: custom_table, company: custom_table.company, user: object.user)
    end
  end


  factory :timeline_custom_table_with_phone_currency_and_text_offboarding_field, parent: :custom_table do
    transient do
      user { nil }
    end
    after(:create) do |custom_table, object|
      create(:currency_field, custom_table: custom_table, display_location: CustomField.display_locations[:offboarding], company: custom_table.company, user: object.user)
      create(:phone_field, custom_table: custom_table, display_location: CustomField.display_locations[:offboarding], company: custom_table.company, user: object.user)
      create(:text_field, custom_table: custom_table, display_location: CustomField.display_locations[:offboarding], company: custom_table.company, user: object.user)
    end
  end

  factory :timeline_custom_table_with_phone_currency_and_text_manager_field, parent: :custom_table do
    transient do
      user { nil }
    end
    after(:create) do |custom_table, object|
      create(:currency_field_with_value, custom_table: custom_table, collect_from: CustomField.collect_froms[:manager], company: custom_table.company, user: object.user)
      create(:phone_field_with_value, custom_table: custom_table, collect_from: CustomField.collect_froms[:manager], company: custom_table.company, user: object.user)
      create(:text_field, :with_value, custom_table: custom_table, company: custom_table.company, user: object.user)
    end
  end

  factory :timeline_custom_table_with_phone_currency_and_text_field_custom_snapshots, parent: :custom_table do
    transient do
      user { nil }
    end
    table_type CustomTable.table_types[:timeline]
    after(:create) do |custom_table, object|
      custom_table.custom_table_user_snapshots << create(:custom_table_user_snapshot, user_id: object.user.id, effective_date: Date.today)
      create(:currency_field_with_snapshot, custom_table: custom_table, company: custom_table.company, custom_table_user_snapshots: custom_table.custom_table_user_snapshots.first)
      create(:phone_field_with_snapshot, custom_table: custom_table, company: custom_table.company, custom_table_user_snapshots: custom_table.custom_table_user_snapshots.first)
      create(:text_field_with_snapshot, custom_table: custom_table, company: custom_table.company, custom_table_user_snapshots: custom_table.custom_table_user_snapshots.first)
    end
  end

  factory :standarad_custom_table_with_phone_currency_and_text_field_custom_snapshots, parent: :custom_table do
    transient do
      user { nil }
    end
    table_type CustomTable.table_types[:standard]
    after(:create) do |custom_table, object|
      custom_table.custom_table_user_snapshots << create(:custom_table_user_snapshot, user_id: object.user.id, effective_date: Date.today)
      create(:currency_field_with_snapshot, custom_table: custom_table, company: custom_table.company, custom_table_user_snapshots: custom_table.custom_table_user_snapshots.first)
      create(:phone_field_with_snapshot, custom_table: custom_table, company: custom_table.company, custom_table_user_snapshots: custom_table.custom_table_user_snapshots.first)
      create(:text_field_with_snapshot, custom_table: custom_table, company: custom_table.company, custom_table_user_snapshots: custom_table.custom_table_user_snapshots.first)
    end
  end
  factory :custom_table_with_approval_chain, parent: :custom_table do
    transient do
      user { nil }
    end

    table_type CustomTable.table_types[:timeline]
    name 'Approval Timeline CustomTable A'
    is_approval_required true
    approval_expiry_time 1
    approval_chains_attributes { attributes_for(:approval_chains) }
    after(:create) do |custom_table, object|
      custom_table.approval_chains << create(:approval_chain, approvable_id: custom_table.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:person], approval_ids: [object.user])
      custom_table.approval_chains << create(:approval_chain, approvable_id: custom_table.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:manager], approval_ids: ['1'])
      custom_table.approval_chains << create(:approval_chain, approvable_id: custom_table.id, approvable_type: 'CustomTable', approval_type: ApprovalChain.approval_types[:person], approval_ids: [object.user])
    end
  end

  factory :approval_custom_table, parent: :custom_table do
    table_type CustomTable.table_types[:timeline]
    name 'Approval Timeline CustomTable A'
    is_approval_required true
    approval_expiry_time 1
    approval_chains_attributes { attributes_for(:approval_chains) }
  end
end
