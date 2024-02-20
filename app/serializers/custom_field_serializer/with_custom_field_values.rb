module CustomFieldSerializer
  class WithCustomFieldValues < Base
    attributes :custom_field_options, :locks
    has_many :custom_field_values, each_serializer: CustomFieldValuesSerializer::Base

    def custom_field_options
       ActiveModelSerializers::SerializableResource.new(object.active_custom_field_options, each_serializer: CustomFieldOptionSerializer::CustomOption) if CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
    end
  end
end
