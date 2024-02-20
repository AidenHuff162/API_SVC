module CompanySerializer
  class CompanyRole < ActiveModel::Serializer
    attributes :id, :role_types, :time_zone, :company_plan
  end
end
