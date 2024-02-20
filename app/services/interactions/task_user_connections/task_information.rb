module Interactions
  module TaskUserConnections
    module TaskInformation
      
      include TaskScheduleOptions
      
      def extract_tasks_ids(action)
        tuc = user.task_user_connections.in_progress_connections.pluck(:task_id)
        
        tasks.map do |task|
          next if tuc.include?(task['id'])
    
          task = ActiveSupport::HashWithIndifferentAccess.new(task)
          task_object = Task.find_by(id: task['id']) if task['id']
          return if task_object.nil?

          tso = task_object.task_schedule_options
          task['workspace_id'] = task.dig('workspace', 'id')
          if task['task_user_connection'] && task['task_user_connection']["_#{action}"]
            task_info = task_information_hash(task_object, task, tso)
            task_info.merge!(task_scheduling(user, tso, task['deadline_in'], task['before_deadline_in'])) 
          end
        end.compact
      end

      private
    
      def task_information_hash(task_object, task, tso)
        { task_object: task_object, task_owner_id: task['owner_id'], task_deadline_in: task['deadline_in'], 
          task_before_deadline_in: task['before_deadline_in'], task_timeline: task['time_line'],
          task_workspace_id: task['workspace_id'], task_workspace_type: task['workspace_type'],
          send_to_asana: task['send_to_asana'], task_assign_on_timeline: tso['assign_on_timeline'],
          task_due_date_timeline: tso['due_date_timeline'], custom_field_id: task['custom_field_id'] }
      end
    end
  end
end

