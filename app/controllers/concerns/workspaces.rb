module Workspaces
  extend ActiveSupport::Concern

  def workspaces
    if object.role == 'account_owner'
      ActiveModelSerializers::SerializableResource.new(object.company.workspaces, each_serializer: WorkspaceSerializer::Basic, user_id: object.id)
    else
      ActiveModelSerializers::SerializableResource.new(object.workspaces, each_serializer: WorkspaceSerializer::Basic, user_id: object.id)
    end
  end
end