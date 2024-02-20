module CompanySerializer
  class EmployeeRecord < ActiveModel::Serializer
    attributes :id, :prefrences, :team_digest_email
  end
end
