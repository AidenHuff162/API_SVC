module Interactions
  module TaskUserConnections
    module DependentTasks
      def dependent_tucs(dep_tucs, tucs)
        draft_tucs = add_dependant_tucs(dep_tucs, tucs)
        draft_tucs.each do |tuc|
          tuc.update(state: :in_progress)
        end
        return if draft_tucs.blank?
    
        Interactions::Activities::Assign.new(@user, draft_tucs.pluck(:task_id), nil, false).perform
      end
    
      private
    
      def add_dependant_tucs(dep_tucs, tucs)
        draft_tucs = []
        dep_tucs.each do |dep_tuc|
          tucs.each do |tuc|
            dep_tuc.dependent_tuc.push(tuc.id) if dep_tuc.task.dependent_tasks&.include?(tuc.task.id)
          end
          if dep_tuc.completed_dependent_task_count.eql?(dep_tuc.dependent_tuc.length)
            draft_tucs.push(dep_tuc)
          else
            dep_tuc.save!
          end
        end
        draft_tucs
      end
    end
  end
end

