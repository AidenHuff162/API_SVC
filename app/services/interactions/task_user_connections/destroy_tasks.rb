module Interactions
  module TaskUserConnections
    module DestroyTasks
      def destroy_tasks_ids(action)
        tasks.map do |task|
          task = ActiveSupport::HashWithIndifferentAccess.new(task)
          task['id'] if task['task_user_connection'] && task['task_user_connection']["_#{action}"]
        end.compact
      end
    end    
  end 
end
