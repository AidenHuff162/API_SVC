class CompanyValueSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :position
  has_one :company_value_image
end
