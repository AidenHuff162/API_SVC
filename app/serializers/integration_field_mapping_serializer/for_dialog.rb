module IntegrationFieldMappingSerializer
  class ForDialog < ActiveModel::Serializer
    attributes :id, :integration_field_key, :custom_field_id, :preference_field_id, :is_custom, :name, :integration_selected_option, :field_position

    def name
      if object.get_field_mapping_direction == 'integration_mapping'
        object.integration_selected_option&.with_indifferent_access.try(:[], :name)
      else
        object.custom_field_id.nil? && object.preference_field_id == "null" ? "None" : object.get_field_name(@instance_options[:company])
      end
    end
  end
end
