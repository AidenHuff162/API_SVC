module CustomFieldSerializer
  class WithOptionsBasic < Basic
    attributes :custom_field_options

    def custom_field_options
      ActiveModelSerializers::SerializableResource.new(object.active_custom_field_options, each_serializer: CustomFieldOptionSerializer::WithOptionsName)
    end
  end
end
