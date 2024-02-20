module WorkspaceMemberSerializer
  class Short < ActiveModel::Serializer
    type :workspace_member

    attributes :id, :member_role, :member_role_name, :member

    def member_role_name
      object.member_role.titleize
    end

    def member
      ActiveModelSerializers::SerializableResource.new(object.member, serializer: UserSerializer::WithOpenWorkspaceTaskCounts, workspace_id: object.workspace_id)
    end
  end
end
