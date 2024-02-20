FactoryGirl.define do

  factory :integration_field_mapping do
    integration_field_key { Faker::Name.name }
    custom_field_id { CustomField.first.id }
    preference_field_id { nil }
    is_custom { true }
    exclude_in_update { nil }
    exclude_in_create { nil }
    parent_hash { "customInformation" }
    parent_hash_path { "customInformation" }
    field_position { IntegrationFieldMapping.last.field_position + 1 rescue 1 }
  end
end