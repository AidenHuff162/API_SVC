module UserRoleSerializer
  class Simple < ActiveModel::Serializer
    attributes :id, :name, :default_name

    def default_name
      (object.name != 'Super Admin' && object.is_default?) ? object.name + ' (default)' : object.name
    end
  end
end
