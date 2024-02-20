module CustomFieldOptionSerializer
  class WithOnlyOptions < ActiveModel::Serializer
    attributes :id, :option
  end
end
