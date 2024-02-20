module CompanySerializer
  class Short < ActiveModel::Serializer
    attributes :email, :team_digest_email
  end
end
