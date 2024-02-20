FactoryGirl.define do
  factory :profile_template do
    company
    process_type
    factory :onboarding_profile_template do
      name { "US Profile Template" }
      after(:create) do |profile_template|
        section_counts = Hash.new(0)
        profile_template.company.custom_fields.each do |field|
          if field.section.present?
            section = field.section
          elsif field.custom_table_id.present?
            section = field.custom_table_id
          end
          profile_template.profile_template_custom_field_connections.create(profile_template_id: profile_template.id, custom_field_id: field.id, position: section_counts[section])
          section_counts[section] += 1
        end
        profile_template.company.prefrences["default_fields"].each do |field|
          if field["section"].present?
            section = field["section"]
          elsif field["custom_table_property"].present?
            section = profile_template.company.custom_tables.find_by(custom_table_property: field["custom_table_property"]).id
          end
          profile_template.profile_template_custom_field_connections.create(profile_template_id: profile_template.id, default_field_id: field["id"], position: section_counts[section])
          section_counts[section] += 1
        end
      end
    end
    factory :offboarding_profile_template do
      name { "Offboarding Profile Template" }
      after(:create) do |profile_template|
        position = 0
        profile_template.company.prefrences["default_fields"].each do |field|
          if ["td", "ltw", "efr", "tt"].include?(field["id"])
            profile_template.profile_template_custom_field_connections.create(profile_template_id: profile_template.id, default_field_id: field["id"], position: position)
            position += 1
          end
        end
      end
    end
  end
end
