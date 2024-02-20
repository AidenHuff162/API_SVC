class SendWorkspaceInvitationsJob < ApplicationJob
  queue_as :workspace_invitations

  def perform(workspace_id, inviter_id)
    workspace = Workspace.find_by(id: workspace_id)
    inviter = User.find_by(id: inviter_id)
    if workspace.present? && inviter.present?
	    workspace.workspace_members.where.not(member_id: inviter.id).each do |workspace_member|
	      UserMailer.added_to_workspace_email(workspace_member.member, inviter, workspace).deliver_now!
	    end
	  end
  end
end
