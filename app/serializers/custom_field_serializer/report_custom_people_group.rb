module CustomFieldSerializer
  class ReportCustomPeopleGroup < ActiveModel::Serializer
    attributes :id, :name, :custom_field_options

    def custom_field_options
      ActiveModelSerializers::SerializableResource.new(object.active_custom_field_options, each_serializer: CustomFieldOptionSerializer::CustomPeopleGroup) if CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
    end
  end
end
