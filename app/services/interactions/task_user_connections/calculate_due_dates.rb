module Interactions
  module TaskUserConnections
    module CalculateDueDates
      def get_before_due_date(new_task, task, due_dates_from, offboard_user, non_onboarding)
        before_due_date = if due_dates_from
                            before_due_dates(task, due_dates_from.to_date, new_task)
                          elsif offboard_user
                            before_due_dates(task, user.last_day_worked, new_task)
                          elsif non_onboarding || (task[:task_before_deadline_in] && due_date_task?(task[:task_timeline]))
                            before_due_dates(task, user.start_date, new_task) 
                          end
        before_due_date || {}
      end
    
      def get_due_date(user, task, due_dates_from)
        due_date = if due_dates_from
                      if_due_date_from(task, due_dates_from)
                   elsif user.last_day_worked && !user.last_day_worked.past? && task[:task_timeline] == 'immediately' && task[:task_deadline_in] == 0
                    { due_date: Time.current.to_date }
                   elsif task[:task_deadline_in]
                    if @offboard_user
                      { due_date: user.last_day_worked + task[:task_deadline_in].days }
                    else
                      { due_date: user.start_date + task[:task_deadline_in].days }
                    end
                  end
        due_date || {}
      end
    
      def get_due_date_from(due_dates_from)
        due_dates_from.present? ? { from_due_date: due_dates_from } : {}
      end
    
      private
      
      def before_due_dates(task, date, new_task)
        return unless task[:task_before_deadline_in] && task[:task_timeline] && ['later', 'on_due'].include?(task[:task_timeline])
        
        if !task[:task_deadline_in]
          { before_due_date: date + task[:task_before_deadline_in].days }
        elsif task[:task_timeline] == 'later'
          { before_due_date: new_task[:due_date].to_date + task[:task_before_deadline_in].days }
        else
          { before_due_date: (new_task[:due_date].to_date + 1) + task[:task_before_deadline_in].days } 
        end
      end
    
      def if_due_date_from(task, due_dates_from)
        if task[:task_deadline_in]
          { due_date: due_dates_from.to_date + task[:task_deadline_in].days }
        elsif task[:task_timeline] == 'immediately' && task[:task_object].deadline_in.positive?
          { due_date: due_dates_from.to_date }
        elsif task[:task_timeline] == 'immediately'
          { due_date: due_dates_from.to_date + task[:task_object].deadline_in.days }
        end
      end

      def due_date_task?(type)
        type && ['later', 'on_due'].include?(type)
      end
    end
  end
end
