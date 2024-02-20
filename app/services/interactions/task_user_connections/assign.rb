module Interactions
  module TaskUserConnections
    class Assign

      include CreateTasks
      include DestroyTasks
      include DependentTasks
      include CreateTaskNotifications
      include CalculateDueDates
      include CreateTaskConnections
      
      attr_reader :user, :tasks, :task_types, :offboard_user, :non_onboarding, :due_dates_from, :agent_id, :created_through_onboarding

      DATE_FORMAT = '%m/%d/%Y'

      def initialize(user, tasks, offboard_user=false, non_onboarding=false, due_dates_from=nil, agent_id=nil, rehire=false, created_through_onboarding = false)
        @user = user
        @company = Company.includes(:integrations).find_by(id: @user.company_id)
        @tasks = tasks
        @task_types = get_hashed_tasks[:task_types]
        @offboard_user = offboard_user
        @non_onboarding = non_onboarding
        @due_dates_from = due_dates_from
        @agent_id = agent_id
        @rehire = rehire
        @created_through_onboarding = created_through_onboarding
      end

      def perform
        task_ids = []
        tucs = []
        dep_tucs = []
        ActiveRecord::Base.transaction do
          new_tasks = tasks_to_create(@user, @tasks, @offboard_user, @non_onboarding, @due_dates_from, @agent_id, 
                                      @created_through_onboarding)
          deleted_task_ids = destroy_tasks_ids(:destroy)
          user.task_user_connections.where(task_id: deleted_task_ids).destroy_all if deleted_task_ids.present?
          return if new_tasks.blank? 

          if deleted_task_ids.empty?
            task_ids, tucs, dep_tucs = create_task_user_connections(user, new_tasks, task_ids, tucs, dep_tucs)
          end
        end

        dependent_tucs(dep_tucs, tucs) if dep_tucs.present?
        user.offboard_user(task_ids) if offboard_user
        create_task_notifications(user, task_ids, tasks, @due_dates_from, @company) if !created_through_onboarding
      end

      private

      def get_hashed_tasks
        hashed_tasks = { task_types: [], task_ids: [] }
        tasks.map do |task|
          task = ActiveSupport::HashWithIndifferentAccess.new(task)
          hashed_tasks[:task_types].push(task['task_type'])
          hashed_tasks[:task_ids].push(task['id'])
        end.compact

        hashed_tasks
      end
    end
  end
end
