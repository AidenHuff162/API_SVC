module WorkspaceSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :workspace_role, :workspace_image
    belongs_to :workspace_image, serializer: WorkspaceImageSerializer

    def workspace_role
      role = object.company.users.find_by(id: @instance_options[:user_id]).try(:role)
      if role && role == 'account_owner'
        "admin"
      else
        object.workspace_members.find_by(member_id: @instance_options[:user_id])&.member_role if @instance_options[:user_id]
      end
    end
  end
end
