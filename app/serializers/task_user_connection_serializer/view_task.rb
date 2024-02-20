module TaskUserConnectionSerializer
  class ViewTask < ActiveModel::Serializer
    attributes :description, :attachments

    belongs_to :workspace, serializer: WorkspaceSerializer::Minimal

    def description
      object.get_task_description
    end

    def attachments
      ActiveModelSerializers::SerializableResource.new(object.task.attachments, each_serializer: AttachmentSerializer)
    end
  end
end
