module CompanySerializer
  class ApiPage < ActiveModel::Serializer
    attributes :id, :name, :webhook_feature_flag
  end
end
