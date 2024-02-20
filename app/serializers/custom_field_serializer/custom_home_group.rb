module CustomFieldSerializer
  class CustomHomeGroup < ActiveModel::Serializer
    attributes :id, :name, :custom_field_options

    def custom_field_options
      if @instance_options[:user_id] && CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
        option = object.active_custom_field_options.joins(:custom_field_values).where(custom_field_values: {user_id: @instance_options[:user_id]}).first
        if option
          ActiveModelSerializers::SerializableResource.new(option, serializer: CustomFieldOptionSerializer::CustomHomeGroup, exclude_users: true)
        else
          nil
        end
      end
    end
  end
end
