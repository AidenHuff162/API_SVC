module ProfileTemplateCustomFieldConnectionSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :required, :position, :custom_field_id, :default_field_id, :field

    def field
      if object.custom_field_id
        ActiveModelSerializers::SerializableResource.new(object.custom_field, serializer: CustomFieldSerializer::Base)
      else
        nil
      end
    end

  end
end
