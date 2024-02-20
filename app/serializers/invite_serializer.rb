class InviteSerializer < ActiveModel::Serializer
  attributes :id, :user_id, :subject, :cc, :bcc, :description
end
