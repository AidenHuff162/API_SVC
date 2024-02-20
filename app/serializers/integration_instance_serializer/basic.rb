module IntegrationInstanceSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :state, :sync_status, :synced_at, :unsync_records_count, :name, :integration_credentials

    def integration_credentials
    	ActiveModelSerializers::SerializableResource.new(object.visible_integration_credentials.includes(:integration_configuration), each_serializer: IntegrationCredentialSerializer::Full)
    end

    def integration_field_mappings
      ActiveModelSerializers::SerializableResource.new(object.integration_field_mappings, each_serializer: IntegrationFieldMappingSerializer::ForDialog, company: @instance_options[:company])
    end
  end
end
