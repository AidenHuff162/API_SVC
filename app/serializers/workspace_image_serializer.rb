class WorkspaceImageSerializer < ActiveModel::Serializer
  attributes :id, :image
  has_one :image
end
