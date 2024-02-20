module CompanySerializer
  class WebhookDialog < ActiveModel::Serializer
    attributes :id, :name, :default_field_prefrences, :zapier_feature_flag

    def default_field_prefrences
      prefrences = []
      object.prefrences["default_fields"].each do |field|
        unless ['user id', 'profile photo', 'access permission', 'effective date'].include?(field["name"].downcase)
          prefrences << { id: field["id"] , api_field_id: field["api_field_id"], name: field["name"], section: field["section"], profile_setup: field["profile_setup"], custom_table_property: field["custom_table_property"] }
        end
      end
      prefrences
    end

  end
end
