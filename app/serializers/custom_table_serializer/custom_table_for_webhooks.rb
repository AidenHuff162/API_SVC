module CustomTableSerializer
  class CustomTableForWebhooks < ActiveModel::Serializer
    attributes :id, :name, :table_type, :custom_table_property, :custom_fields
    
    def custom_fields
      ActiveModelSerializers::SerializableResource.new(object.custom_fields.with_excluded_fields_for_webhooks, each_serializer: CustomFieldSerializer::ForWebhooks)
    end
  end
end
