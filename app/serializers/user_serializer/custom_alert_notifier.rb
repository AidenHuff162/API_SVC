module UserSerializer
  class CustomAlertNotifier < ActiveModel::Serializer
    attributes :id, :picture, :first_name, :last_name, :preferred_name, :display_name_format

    def display_name_format
      object.company.try(:display_name_format) rescue 0
    end
  end
end
