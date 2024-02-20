module CustomFieldValuesSerializer
  class CustomGroup < ActiveModel::Serializer
    attributes :id, :custom_field_option_id, :user_id, :custom_field_id, :user

    def user
      if object.user
        ActiveModelSerializers::SerializableResource.new(object.user, serializer: UserSerializer::Basic)
      else
        nil
      end
    end
  end
end
