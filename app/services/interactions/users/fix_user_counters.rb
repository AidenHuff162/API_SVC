module Interactions
  module Users
    class FixUserCounters
      attr_reader :current_user, :update_current

      def initialize(current_user, update_current=false)
        @current_user = current_user
        @update_current = update_current
      end

      def perform
        update_user_count(current_user) if update_current

        users_to_update = current_user.assignees
        users_to_update += User.where(id: current_user.task_owner_connections.joins(:user).pluck("users.id"))
        users_to_update.uniq!

        users_to_update.each do |user|
          update_user_count(user)
        end
      end

      private

      def update_user_count(user)
        user.update_column(:outstanding_tasks_count, outstanding_tasks_count(user))
        user.update_column(:outstanding_owner_tasks_count, outstanding_owner_tasks_count(user))
        # active documents count
        user.update_column(:incomplete_upload_request_count, incomplete_upload_request_count(user))
        user.update_column(:incomplete_paperwork_count, incomplete_paperwork_count(user))
        user.update_column(:co_signer_paperwork_count, co_signer_paperwork_count(user))
      end

      def outstanding_tasks_count(user)
        calculated_count = TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                            .where(user_id: user.id, state: 'in_progress').count
        calculated_count = 0 if calculated_count < 0
        calculated_count
      end

      def outstanding_owner_tasks_count(user)
        calculated_count = TaskUserConnection.joins(:user)
                          .where(owner_id: user.id, state: 'in_progress')
                          .where("(users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                          .joins(:task).where.not(tasks: {task_type: '4'})
                          .count
        calculated_count = 0 if calculated_count < 0
        calculated_count
      end

      def incomplete_upload_request_count(user)
        calculated_count = user.user_document_connections.joins(:document_connection_relation).where(state: 'request').count
        calculated_count = 0 if calculated_count < 0
        calculated_count
      end

      def incomplete_paperwork_count(user)
        calculated_count = user.paperwork_requests.joins(:document).where(state: ['assigned', 'preparing', 'failed']).count
        calculated_count = 0 if calculated_count < 0
        calculated_count
      end

      def co_signer_paperwork_count(user)
        calculated_count = user.paperwork_requests_to_co_sign.count
        calculated_count = 0 if calculated_count < 0
        calculated_count
      end
    end
  end
end
