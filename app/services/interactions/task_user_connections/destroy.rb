module Interactions
  module TaskUserConnections
    class Destroy
       attr_reader :tasks, :owner_id

      def initialize(owner_id, tasks)
        @owner_id = owner_id
        @tasks = tasks
      end

      def perform
        ActiveRecord::Base.transaction do
          TaskUserConnection.where(owner_id: owner_id, task_id: tasks_ids_to_destroy).destroy_all
        end
      end

      private
      def tasks_ids_to_destroy
        @tasks_ids_to_destroy ||= extract_tasks_ids(:destroy)
      end

      def extract_tasks_ids(action)
        tasks.map do |task|
          task[:id] if task[:task_user_connection] && task[:task_user_connection][:"_#{action}"]
        end.compact
      end
    end
  end
end
