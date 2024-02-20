module CustomFieldSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :section, :position, :name, :help_text, :default_value, :field_type,
      :required, :required_existing, :collect_from, :api_field_id, :custom_table_id,
      :custom_table_property, :profile_setup, :display_location, :is_sensitive_field, :lever_requisition_field_id,
      :used_in_templates

    def custom_table_property
      object.custom_table.try(:custom_table_property) if object.custom_table_id
    end

    def profile_setup
      object.custom_table_id ? 'custom_table' : 'profile_fields'
    end

    def used_in_templates
      ProfileTemplate.joins(:profile_template_custom_field_connections).where(profile_template_custom_field_connections: {custom_field_id: object.id}).pluck(:name)
    end
  end
end
