module Interactions
  module TaskUserConnections
    module HandleTaskScheduleOptionsAssignment
      def handle_task_schedule_options_assignment(task, new_task)
        assign_relative_date(task, new_task) if task[:assign_on_relative_key_date] || relative_due_date_exists?(task)          
        assign_custom_date(task, new_task) if task[:assign_on_custom_date] || task[:due_date_custom_date]
        manage_due_date(new_task)
        new_task
      end
    
      private

      def assign_custom_date(task, new_task)
        if task[:assign_on_custom_date]
          task[:assign_on_custom_date] = Date.strptime(task[:assign_on_custom_date], 
                                                       DATE_FORMAT) rescue task[:assign_on_custom_date].to_date
          new_task[:before_due_date] = task[:assign_on_custom_date]
        end
        if task[:due_date_custom_date]
          new_task[:due_date] = task[:due_date_custom_date].to_date
        end
        new_task
      end
    
      def assign_relative_date(task, new_task)
        get_relative_assign_on_date(task, new_task) if task[:assign_on_relative_key_date]
        get_relative_due_date(task, new_task) if relative_due_date_exists?(task)
      end
    
      def relative_due_date_exists?(task)
        task[:due_date_relative_key_date].present? && (['immediately', 'dependent'].exclude?(task[:timeline]) || 
        task[:task_object]&.task_schedule_options&['due_date_relative_key'] != 'after_task_is_assigned' || 
        @due_dates_from.blank?)
      end

      def get_relative_assign_on_date(task, new_task)
        assign_on_offset_time = task[:task_object]&.before_deadline_in || 0
        new_task[:before_due_date] = task[:assign_on_relative_key_date] + assign_on_offset_time
        if task[:task_timeline] != 'on_due' && task[:task_object]&.task_schedule_options["due_date_relative_key"] == 'after_task_is_assigned'
          new_task[:due_date] = task[:assign_on_relative_key_date] + assign_on_offset_time
        end
        new_task
      end

      def get_relative_due_date(task, new_task)
        due_date_offset_time = task[:task_deadline_in]&.days || 0
        new_task[:due_date] = task[:due_date_relative_key_date] + due_date_offset_time
        new_task
      end

      def manage_due_date(new_task)
        relative_date = new_task[:before_due_date] || Date.current
        new_task[:due_date] = relative_date if relative_date && relative_date > new_task[:due_date]
        new_task
      end
    end
  end
end

