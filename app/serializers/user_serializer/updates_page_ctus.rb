module UserSerializer
  class UpdatesPageCtus < ActiveModel::Serializer
    attributes :id, :picture, :name, :preferred_name, :first_name, :last_name, :display_name

    def name
      object.try(:full_name)
    end
  end
end
