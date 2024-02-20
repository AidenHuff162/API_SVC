module Api
  module V1
    module Admin
      class TaskUserConnectionsController < BaseController
        before_action :authorize_tasks

        load_and_authorize_resource :user

        def bulk_assign
          BulkWorkflowAssignmentJob.perform_later(params.to_h, current_user)
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def assign
          interaction = if params[:non_onboarding] && assign_params.present?
                          Interactions::TaskUserConnections::Assign.new(@user,
                                                          assign_params,
                                                          false,
                                                          true,
                                                          params[:due_dates_from],
                                                          current_user.id,
                                                          false,
                                                          params[:created_through_onboarding])
                        elsif !params[:owner_id] && assign_params.present?
                          Interactions::TaskUserConnections::Assign.new(@user,
                                                                        assign_params,
                                                                        false,
                                                                        false,
                                                                        params[:due_dates_from],
                                                                        current_user.id,
                                                                        params[:rehire],
                                                                        params[:created_through_onboarding])
                        else
                          Interactions::TaskUserConnections::Destroy.new(params[:owner_id],
                                                                         assign_params)
                        end

          interaction.perform
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def destroy_by_filter
          interaction = Interactions::TaskUserConnections::DestroyByWorkstream.new(workstream_params)
          interaction.perform

          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def bulk_update_task_user_conenctions
          data = params[:data]
          return if !data
          OffBoard::ReassignTaskUserConnectionsJob.perform_later(data, params[:notify_new_owners])
          render body: Sapling::Application::EMPTY_BODY, status: 200
        end

        def unassign
          if params[:unassign_tasks_ids].present?
            tucs = TaskUserConnection.joins(task: {workstream: :company}).where(task_user_connections: { user_id: params[:onboard_user_id], id: params[:unassign_tasks_ids]}, companies: {id: current_company.id})
            unless tucs.empty?
              sub_tucs = SubTaskUserConnection.where(task_user_connection_id: tucs.pluck(:id))
              unless sub_tucs.empty?
                sub_tucs.destroy_all
                sub_tucs.delete_all
              end
              user = current_company.users.find_by(id: params[:onboard_user_id])
              user.outstanding_tasks_count -= tucs.count
              user.save
              tucs.destroy_all
              tucs.delete_all
              create_general_logging(current_company, "User #{current_user.id} unassigned tasks created for user #{params[:onboard_user_id]} during the onboarding flow", nil)
            end
          end
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        private

        def workstream_params
          params.permit(:workstream_id, :user_id, :owner_id, :filter, :due_date, :send_to_asana).merge(company_id: current_company.id)
        end

        def assign_params
          params.to_h[:tasks] || []
        end

        def authorize_tasks
          tasks = Task.includes([:workstream]).find_by_sql(["select tasks.* from tasks inner join workstreams on workstreams.id = tasks.workstream_id inner join companies on companies.id = workstreams.company_id and companies.id = ? where tasks.id IN (?)",current_company.id,tasks_ids])
          tasks.each do |task|
            if task
              authorize! :manage, task
            end
          end
        end

        def tasks_ids
          tasks_ids ||= assign_params.map { |task| task[:id] }
        end

      end
    end
  end
end
