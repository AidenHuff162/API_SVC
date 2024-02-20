module WorkspaceSerializer
  class Simple < ActiveModel::Serializer
    attributes :id, :name, :workspace_image

    def workspace_image
      object.workspace_image
    end
  end
end
