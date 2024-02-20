module CustomTables
  class AssignSnapshotsAndDocuments < ApplicationJob
    queue_as :manage_custom_snapshots

    def perform(user_id, current_user_id, custom_table_user_snapshot)
      ::CustomTables::AssignCustomFieldValue.new.assign_values_to_user(custom_table_user_snapshot)
      user = User.find(user_id)
      return unless user.user_document_connections.draft_connections || user.paperwork_requests.draft_requests

      SmartAssignmentIndividualPaperworkRequestJob.perform_later(user_id, user.company_id, current_user_id)
    end
  end
end
