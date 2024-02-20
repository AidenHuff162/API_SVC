module Interactions
  module Activities
    class ScheduleTasks

      def perform
        user_ids = TaskUserConnection.where(state: 'in_progress', before_due_date: Date.today).pluck(:user_id).uniq
        user_ids.try(:each) do |user_id|
          task_ids = TaskUserConnection.where(state: 'in_progress', user_id: user_id, before_due_date: Date.today).pluck(:task_id).uniq
          user = User.find_by(id: user_id)
          if user.present?
            if ["registered", "offboarding", "departed", "last_month", "last_week"].include?(user.current_stage)
              Interactions::Activities::Assign.new(user, task_ids).perform if task_ids.present?
            else
              Interactions::Activities::Assign.new(user, task_ids, nil, true).perform if task_ids.present?
            end
          end
        end
      end
    end
  end
end
