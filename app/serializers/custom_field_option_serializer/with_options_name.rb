module CustomFieldOptionSerializer
  class WithOptionsName < ActiveModel::Serializer
    attributes :id, :name

    def name
      object.option
    end
  end
end
