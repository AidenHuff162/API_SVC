class ProfileSerializer < ActiveModel::Serializer
  attributes :id, :user_id, :facebook, :twitter, :linkedin, :about_you, :github
end
