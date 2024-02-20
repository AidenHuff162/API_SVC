module Interactions
  module TaskUserConnections
    module CreateTasks

      include TaskInformation
      include TaskTypes
      include HandleTaskScheduleOptionsAssignment
      include CalculateDueDates
    
      def tasks_to_create(user, tasks, offboard_user, non_onboarding, due_dates_from, agent_id, 
                          created_through_onboarding)
        tasks_information = extract_tasks_ids(:create)
        return unless tasks_information.present?
        
        task_objects = tasks_information.map(&:first) 
        return if task_objects.empty?
    
        get_new_task_hash(tasks_information, user, due_dates_from, offboard_user, non_onboarding, agent_id, 
                          created_through_onboarding)
      end
    
      private
    
      def task_schedule_options?(task)
        task[:assign_on_relative_key_date] || task[:due_date_relative_key_date] || task[:assign_on_custom_date] || 
        task[:due_date_custom_date]
      end
    
      def task_timeline_option?(task)
        task[:task_before_deadline_in] && task[:task_timeline] && task[:task_timeline] == 'later'
      end
    
      def get_task_due_date(user, task, new_task, due_dates_from, offboard_user, non_onboarding)
        new_task.merge!(get_due_date(user, task, due_dates_from), get_due_date_from(due_dates_from))
        new_task.merge!(get_before_due_date(new_task, task, due_dates_from, offboard_user, non_onboarding))
      end
    
      def get_task_assign_date(new_task)
        assign_date = new_task[:before_due_date]&.to_date || new_task[:from_due_date]&.to_date || Date.current
        #new_task[:due_date] = assign_date if assign_date && (assign_date > new_task[:due_date].to_date)
        new_task
      end
    
      def get_new_task_hash(tasks_information, user, due_dates_from, offboard_user, non_onboarding, agent_id, 
                            created_through_onboarding)
        tasks_information.map do |task|
          new_task = { task_id: task[:task_object].id, agent_id: agent_id, send_to_asana: task[:send_to_asana] }
          new_task = get_task_due_date(user, task, new_task, due_dates_from, offboard_user, non_onboarding)
          new_task = get_task_assign_date(new_task)
    
          new_task[:is_offboarding_task] = true if offboard_user
          new_task[:created_through_onboarding] = true if created_through_onboarding
          new_task[:schedule_days_gap] = task[:task_before_deadline_in] if task_timeline_option?(task)
          new_task = handle_task_schedule_options_assignment(task, new_task) if task_schedule_options?(task)
    
          task_type = get_task_types(task, user)
          new_task.merge!(task_type) if task_type
        end.compact
      end
    end    
  end
end
