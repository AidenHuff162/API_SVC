module Interactions
  module TaskUserConnections
    module TaskScheduleOptions
      def task_scheduling(user, task_schedule_options, deadline_in, before_deadline_in)
        { assign_on_relative_key_date: get_assign_on_relative_key_date(task_schedule_options, deadline_in), 
          due_date_relative_key_date: get_due_date_relative_key_date(task_schedule_options, before_deadline_in), 
          assign_on_custom_date: get_assign_on_custom_date(task_schedule_options), 
          due_date_custom_date: get_due_date_custom_date(task_schedule_options) }
      end
    
      private
    
      def get_assign_on_relative_key_date(tso, deadline_in = 0)
        if tso['assign_on_relative_key'] == 'when_task_is_due'
          key_date = relative_key_date(tso, 'due_date')
          key_date += deadline_in unless tso['due_date_custom_date']   
        else
          key_date = get_key_date(tso['assign_on_relative_key'])
        end
      end
    
      def get_due_date_relative_key_date(tso, before_deadline_in = 0)
        if tso['due_date_relative_key'] == 'after_task_is_assigned' 
          key_date = relative_key_date(tso, 'assign_on')
          key_date += before_deadline_in unless tso['assign_on_custom_date']
        else
          key_date = get_key_date(tso['due_date_relative_key'])
        end
      end
    
      def get_assign_on_custom_date(tso)
        tso['assign_on_custom_date']
      end
    
      def get_due_date_custom_date(tso)
        tso['due_date_custom_date']
      end
    
      def relative_key_date(tso, timeline)
        case timeline
        when 'due_date'
          get_due_date_relative_key_date(tso) || tso['due_date_custom_date']&.to_date
        when 'assign_on'
          get_assign_on_relative_key_date(tso) || tso['assign_on_custom_date']&.to_date
        end || Date.current
      end
    
      def get_key_date(relative_key)
        case relative_key
        when 'start_date'
          user.start_date
        when 'anniversary'
          user.get_next_yearly_anniversary_date(user.start_date)
        when 'last_day_worked'
          user.last_day_worked
        when 'last_day_of_work'
          user.last_day_worked
        when 'termination_date'
          user.termination_date
        end
      end
    end
  end
end

