module WorkspaceEmailService
  class Invitations
    attr_reader :current_user, :workspace, :invite_user

    def initialize current_user, workspace, invite_user
      @current_user = current_user
      @workspace = workspace
      @invite_user = invite_user
    end

    def invite_members
      SendWorkspaceInvitationsJob.perform_later(@workspace.id, @current_user.id)
    end

    def invite_member
      UserMailer.added_to_workspace_email(@invite_user, @current_user, @workspace).deliver_now!
    end

  end
end
