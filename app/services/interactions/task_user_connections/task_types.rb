module Interactions
  module TaskUserConnections
    module TaskTypes
      def get_task_types(task, user)
        task_type = task[:task_object].task_type
        case task_type
        when 'workspace' 
          task_type_workspace(task, user)
        when 'coworker'
          task_type_coworker(task, user)
        when 'manager'
          if task[:task_owner_id].present?
            { owner_id: task[:task_owner_id] }
          else
            user.manager_id ? { owner_id: user.manager_id } : {}
          end
        when 'buddy'
          if task[:task_owner_id].present?
            { owner_id: task[:task_owner_id] }
          else
            user.buddy_id ? { owner_id: user.buddy_id } : {}
          end
        else
          other_task_type(task, task_type)
        end
      end
    
      private
    
      def task_type_workspace(task, user)
        return unless task[:task_workspace_id]
    
        if task[:task_workspace_type] && task[:task_workspace_type] == 'individual'
          { owner_id: task[:task_owner_id],
            workspace_id: task[:task_workspace_id], 
            owner_type: TaskUserConnection.owner_types[:individual] }
        elsif !task[:task_workspace_type]
          { owner_id: user.id, 
            workspace_id: task[:task_workspace_id], 
            owner_type: TaskUserConnection.owner_types[:workspace] }
        end
      end
    
      def task_type_coworker(task, user)
        custom_field = CustomFieldValue.find_by(user_id: user.id, custom_field_id: task[:custom_field_id])
        return unless custom_field&.coworker_id&.present?
        
        { owner_id: custom_field.coworker_id }
      end
    
      def other_task_type(task, task_type)
        if ['jira', 'hire', 'service_now'].include?(task_type)
          { owner_id: user.id }
        elsif task[:task_owner_id]
          { owner_id: task[:task_owner_id] }
        else
          { owner_id: task[:task_object].owner_id }
        end
      end
    end
  end
end

