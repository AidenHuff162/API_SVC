module ProfileTemplateSerializer
  class WithConnections < ActiveModel::Serializer
    attributes :id, :name, :edited_by_id, :meta, :process_type_id, :updated_at, :users_count, :process_type, :profile_template_custom_table_connections, :profile_template_custom_field_connections

    def profile_template_custom_table_connections
      ActiveModelSerializers::SerializableResource.new(object.profile_template_custom_table_connections, each_serializer: ProfileTemplateCustomTableConnectionSerializer::Base)
    end

    def profile_template_custom_field_connections
      ActiveModelSerializers::SerializableResource.new(object.profile_template_custom_field_connections, each_serializer: ProfileTemplateCustomFieldConnectionSerializer::Base)
    end

  end
end
