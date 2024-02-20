FactoryGirl.define do
  factory :custom_table_user_snapshot do
  	state CustomTableUserSnapshot.states[:processed]
    request_state nil
  	custom_table
  	user { build(:user) }

  	factory :standard_without_approval, parent: :custom_table_user_snapshot do
  	end
    
    factory :employement_status_snapshot_with_effective_date, parent: :custom_table_user_snapshot do
      effective_date 5.days.ago
      is_terminated true
      after(:create) do |snapshot|
        create(:custom_snapshot, custom_table_user_snapshot: snapshot, custom_field_value: snapshot.user.termination_date.to_s, custom_field: CustomTable.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status]).custom_fields.find_by(name: "Effective Date"))
      end
    end
  	
    factory :timeline_without_approval, parent: :custom_table_user_snapshot do
  		state CustomTableUserSnapshot.states[:queue]
  		effective_date Date.today
  	end

  	factory :timeline_with_approval, parent: :custom_table_user_snapshot do
  		state CustomTableUserSnapshot.states[:queue]
  		effective_date Date.today
  		request_state CustomTableUserSnapshot.request_states[:requested]
  	end

    factory :standard_with_custom_snapshots, parent: :custom_table_user_snapshot do
      custom_snapshots_attributes { attributes_for(:custom_snapshots) }
    end

    factory :timeline_without_approval_with_custom_snapshots, parent: :custom_table_user_snapshot do
      custom_snapshots_attributes { attributes_for(:custom_snapshots) }
    end

    factory :timeline_with_approval_with_custom_snapshots, parent: :custom_table_user_snapshot do
      custom_snapshots_attributes { attributes_for(:custom_snapshots) }
      request_state CustomTableUserSnapshot.request_states[:requested]
    end
  end

  factory :role_information_custom_snapshot, parent: :custom_table_user_snapshot do
    after(:create) do |ctus|
      create(:custom_snapshot, custom_table_user_snapshot_id: ctus.id, preference_field_id: 'man', custom_field_value: create(:user, company: ctus.custom_table.company).id)
      create(:custom_snapshot, custom_table_user_snapshot_id: ctus.id, preference_field_id: 'jt', custom_field_value: '1')
      create(:custom_snapshot, custom_table_user_snapshot_id: ctus.id, preference_field_id: 'dpt', custom_field_value: create(:team, company: ctus.custom_table.company).id)
      create(:custom_snapshot, custom_table_user_snapshot_id: ctus.id, preference_field_id: 'loc', custom_field_value: create(:location, company: ctus.custom_table.company).id)
    end
  end

  factory :employment_status_custom_snapshot, parent: :custom_table_user_snapshot do
    after(:create) do |ctus|
      create(:custom_snapshot, custom_table_user_snapshot_id: ctus.id, preference_field_id: 'st', custom_field_value: 'active')
    end
  end
end
