module WorkspaceSerializer
  class Minimal < ActiveModel::Serializer
    attributes :id, :name, :workspace_image
    belongs_to :workspace_image, serializer: WorkspaceImageSerializer
  end
end
