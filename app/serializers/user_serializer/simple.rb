module UserSerializer
  class Simple < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :preferred_name, :title, :picture, :display_name_format

    def display_name_format
      object.company.display_name_format
    end

  end
end
