module UserSerializer
  class CannyIdentify < ActiveModel::Serializer
    attributes :id, :email, :full_name, :created_at, :title, :current_stage, :last_active, :personal_email, :role, :start_date, :guid, :created_by_source
    belongs_to :company, serializer: CompanySerializer::CannyIdentifyCompany
  end
end