module CustomFieldSerializer
  class Basic < ActiveModel::Serializer
  	attributes :id, :name , :field_type
  end
end