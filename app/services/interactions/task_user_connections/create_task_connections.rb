module Interactions
  module TaskUserConnections
    module CreateTaskConnections
      def create_task_user_connections(user, new_tasks, task_ids, tucs, dep_tucs)
        user.task_user_connections.create!(new_tasks).each do |connection|
          dep_tucs.push(connection) unless check_dependent_tasks?(connection)
          tucs.push(connection)
          task_ids.push(connection[:id])
        end
        [task_ids, tucs, dep_tucs]
      end

      private

      def check_dependent_tasks?(connection)
        @tasks.detect { |task| task['id'] == connection.task_id && task['dependent_tasks']&.empty? }
      end
    end
  end
end
