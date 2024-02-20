module WorkspaceSerializer
  class Onboard < ActiveModel::Serializer
    attributes :id, :name, :workspace_image, :uid

    def uid
      "W#{object.id}"
    end

    def workspace_image
      object.workspace_image.image.url
    end
  end
end
