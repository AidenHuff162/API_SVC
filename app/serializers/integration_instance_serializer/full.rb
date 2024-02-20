module IntegrationInstanceSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :api_identifier, :filters, :integration_credentials, :state, :name, :is_authorized, :connected_at, :connected_by_name, :connected_by_id, :integration_field_mappings
    
    def integration_credentials
    	ActiveModelSerializers::SerializableResource.new(object.visible_integration_credentials.includes(:integration_configuration), each_serializer: IntegrationCredentialSerializer::Full)
    end

    def connected_at
      object.connected_at.to_date.strftime(@instance_options[:company].get_date_format) if object.connected_at.present?
    end

    def connected_by_name
      object.connected_by.try(:display_name)
    end

    def integration_field_mappings
      ActiveModelSerializers::SerializableResource.new(object.integration_field_mappings&.in_order, each_serializer: IntegrationFieldMappingSerializer::ForDialog, company: @instance_options[:company])
    end

  end
end
