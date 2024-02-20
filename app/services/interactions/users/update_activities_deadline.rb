module Interactions
  module Users
    class UpdateActivitiesDeadline
      attr_reader :id, :start_date, :update_activties, :update_termination_activities

      def initialize(id, start_date, update_activties, update_termination_activities, old_start_date)
        @id = id
        @start_date = start_date
        @old_start_date = old_start_date
        @update_activties = update_activties
        @update_termination_activities = update_termination_activities
      end

      def perform
        user = User.find(id)
        update_user_task_date(user)
      end

      private

      def update_user_task_date(user)
        if @update_activties
          user.task_user_connections.where(state: %w[draft in_progress], is_custom_due_date: false).lock.each do |tuc|
            next unless tuc.task

            update_user_activites(tuc, user)
          end
        elsif @update_termination_activities
          user.task_user_connections.where(state: 'in_progress', is_custom_due_date: false).lock.each do |tuc|
            update_user_termination_activites(tuc, user)
          end
        end
      end

      def update_user_activites(tuc, user)
        before_due_date = tuc.before_due_date
        difference = (@start_date - @old_start_date).to_i rescue 0

        if update_task_date?(tuc, tuc.before_due_date.present?, 'assign_on_relative_key')
          tuc.before_due_date = before_due_date + difference.days
        end

        if update_task_date?(tuc, tuc.task.present?, 'due_date_relative_key')
          tuc.due_date = tuc.due_date + difference.days
        elsif update_task_dates_using_termination_date?(tuc, user)
          tuc.due_date = user.termination_date + tuc.task.deadline_in.days 
          tuc.before_due_date = user.termination_date + tuc.task.before_deadline_in.days
        elsif update_task_dates_using_start_date?(tuc)
          tuc.due_date = @start_date + tuc.task.deadline_in.days 
          tuc.before_due_date = @start_date + tuc.task.before_deadline_in.days
        end

        if (tuc.before_due_date && tuc.due_date < tuc.before_due_date)
          tuc.due_date = tuc.before_due_date
        end

        tuc.save!
      end

      def update_user_termination_activites(tuc, user)
        update_termination_date(tuc, user) if tuc.task.present? && user.termination_date.present?
        update_before_due_date(tuc) if tuc.before_due_date && tuc.due_date < tuc.before_due_date
      end

      def update_task_date?(tuc, task, key)
        (task &&
         %w[start_date anniversary].include?(tuc.task.task_schedule_options[key]))
      end

      def update_task_dates_using_termination_date?(tuc, user)
        (tuc.task.present? && !tuc.before_due_date&.past? &&
         tuc.task.task_schedule_options['due_date_relative_key'] == 'termination_date' &&
         task_deadline?(tuc, user))
      end

      def update_task_dates_using_start_date?(tuc)
        (tuc.task.task_schedule_options['due_date_custom_date'].blank? && @start_date.present? &&
         tuc.task.deadline_in.present? && !tuc.before_due_date&.past? && tuc.task.before_deadline_in.present?)
      end

      def task_deadline?(tuc, user)
        (user.termination_date.present? && tuc.task.deadline_in.present? && tuc.task.before_deadline_in.present?)
      end

      def update_termination_date(tuc, user)
        tuc.update!(due_date: user.termination_date + tuc.task.deadline_in.days)
      end

      def update_before_due_date(tuc)
        tuc.update!(due_date: tuc.before_due_date)
      end
    end
  end
end
