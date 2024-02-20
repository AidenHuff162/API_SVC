module Api
  module V1
    module Admin
      class WorkstreamsController < BaseController
        include AttachmentSharedMethods
        before_action :require_company!
        load_and_authorize_resource except: [:connected]

        before_action only: [:index, :basic] do
          if params[:offboarding_view] && action_name == "basic"
            ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab], "offboard_workstreams")
          else
            ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
          end
        end
        before_action only: [:basic] do
          if params[:offboarding_view] && action_name == "basic"
            ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, params[:sub_tab], "offboard_workstreams")
          else
            ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, params[:sub_tab])
          end
        end

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
        end

        load_resource :user, only: [:connected]
        authorize_resource only: [:connected]

        def create
          @workstream.save!
          respond_with @workstream, serializer: WorkstreamSerializer::Base
          PushEventJob.perform_later('workstream-created', current_user, {
            workstream_name: @workstream[:name],
            tasks_count: @workstream[:tasks_count]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.workstream.created', name: @workstream[:name])
          })

          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.workstream.created', name: @workstream[:name])
          })
        end

        def show
          respond_with @workstream, include: ['tasks.owner'], serializer: WorkstreamSerializer::WithConnections, user_id: params[:user_id], include: '**'
        end

        def index
          collection = WorkstreamsCollection.new(collection_params)
          respond_with collection.results,
          include: ['tasks.owner'],
          each_serializer: WorkstreamSerializer::Base
        end

        def get_workstream_with_sorted_tasks
          respond_with @workstream, include: ['tasks.owner'], serializer: WorkstreamSerializer::WithSortedTasks, user_id: params[:user_id], sort_type: params[:sort_type], include: '**'
        end

        def get_workstreams_with_tasks
          collection = WorkstreamsCollection.new(collection_params)
          respond_with collection.results,
          include: ['tasks.owner'],
          each_serializer: WorkstreamSerializer::ForReports,
          with_deleted_workstream_tasks: params[:with_deleted_workstream_tasks]
        end

        def paginated_workstreams
          collection = WorkstreamsCollection.new(paginated_params)
          meta = {
            draw: params[:draw].to_i,
            recordsTotal: collection.nil? ? 0 : collection.results.count,
            recordsFiltered: collection.nil? ? 0 : collection.results.count,
          }
          respond_with collection.results,
                       include: ['tasks.owner'],
                       each_serializer: WorkstreamSerializer::Base,
                       meta: meta,
                       adapter: :json
        end

        def get_active_tasks
          collection = WorkstreamsCollection.new(collection_params)
          respond_with collection.results, include: ['tasks.task_user_connections', 'tasks.owner'],
          owner_id: params[:owner_id],
          each_serializer: WorkstreamSerializer::WithOwnerConnections
        end

        def get_template_tasks
          collection = WorkstreamsCollection.new(collection_params)
          respond_with collection.results,
          task_owner_id: params[:task_owner_id],
          each_serializer: WorkstreamSerializer::WithTasks
        end

        def basic
          collection = WorkstreamsCollection.new(collection_params)
          respond_with collection.results,
          each_serializer: WorkstreamSerializer::Basic
        end

        def destroy
          PushEventJob.perform_later('workstream-deleted', current_user, {
            workstream_name: @workstream[:name],
            tasks_count: @workstream[:tasks_count]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.workstream.deleted', name: @workstream[:name])
          })
          if Rails.env == "test"
            @workstream.really_destroy!
          else
            @workstream.destroy!
          end
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.workstream.deleted', name: @workstream[:name])
          })
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def update
          @workstream.update!(workstream_params)
          respond_with @workstream, serializer: WorkstreamSerializer::WithConnections
          PushEventJob.perform_later('workstream-updated', current_user, {
            workstream_name: @workstream[:name],
            tasks_count: @workstream[:tasks_count]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.workstream.updated', name: @workstream[:name])
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.workstream.updated', name: @workstream[:name])
          })
        end

        def connected
          collection = WorkstreamsCollection.new(collection_params)
          respond_with collection.results,
                       include: ['tasks.task_user_connections', 'tasks.owner', 'tasks.workspace'],
                       user_id: @user.id,
                       each_serializer: WorkstreamSerializer::WithConnections,
                       rehire: params[:rehire]
        end

        def update_task_owners
          if params[:update_task_owner] == "true"
            @workstream.tasks
                       .where(id: params[:task_ids].split(",").map(&:to_i))
                       .update_all(owner_id: params[:new_owner_id], task_type: 'owner')
            respond_with @workstream.tasks.includes(:workspace),
                         each_serializer: TaskSerializer::WithConnections,
                         owner_id: params[:new_owner_id],
                         user_id: params[:user_id],
                         include: '**'

          elsif params[:activities_page] == "true"
            # NOT BEING REFERENCED FROM FRONTEND ANYMORE
            TaskUserConnection.where(id: params[:task_ids].split(",").map(&:to_i)).update_all(owner_id: params[:new_owner_id])
            task_user_connections = @workstream.tasks.map(&:task_user_connections).flatten.select { |tcu| tcu.user_id== params[:user_id] }
            respond_with task_user_connections, each_serializer: TaskUserConnectionSerializer::Base, include: '**'

          else
            head :ok
          end
        end

        def fetch_stream_tasks
          workstream = current_company.workstreams.find_by(id: params[:id])
          if workstream
            tasks = workstream.tasks
            respond_with tasks, each_serializer: TaskSerializer::WithAssignedOwners, user_id: params[:user_id]
          else
            respond_with status: 404
          end
        end

        def get_custom_workstream
          unless current_company.workstreams.find_by(name: "Custom Tasks")
            current_company.create_custom_workstream
          end
          collection = WorkstreamsCollection.new(collection_params.merge(custom_tasks_workstream: true))
          respond_with collection.results, each_serializer: WorkstreamSerializer::Basic
        end

        def duplicate_workstream
          current_workstream = current_company.workstreams.find_by(id: params[:id])
          workstreams = current_company.workstreams.where("position > ?", current_workstream.position)
          if workstreams.present?
            workstreams.update_all("position= position + 1")
          end
          new_workstream = current_workstream.dup
          new_workstream.position = current_workstream.position + 1
          new_workstream.tasks_count = 0
          new_workstream.name = "Copy of #{current_workstream.name}"
          new_workstream.save
          current_workstream.tasks.each do |task|
            new_task = task.dup
            task.sub_tasks.each do |sub_task|
              new_task.sub_tasks.push sub_task.dup
            end
            task.attachments.each do |attachment|
              file = upload_attachment(attachment)
              new_task.attachments.push file if file.present?
            end
            new_task.workstream_id = new_workstream.id
            new_task.save
          end
          respond_with new_workstream, serializer: WorkstreamSerializer::Base
          PushEventJob.perform_later('workstream-created', current_user, {
            workstream_name: new_workstream[:name],
            tasks_count: new_workstream.tasks.count
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.workstream.created', name: new_workstream[:name])
          })

          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.workstream.created', name: new_workstream[:name])
          })
        end

        def duplicate_workstream_task
          current_workstream = current_company.workstreams.find_by(id: params[:id])
          new_workstream = current_workstream.dup
          new_workstream.tasks_count = 0
          new_workstream.name = DuplicateNameService.call(current_workstream.name, current_company.workstreams)
          new_workstream.save
          current_workstream.tasks.each do |task|
            new_task = task.dup
            task.sub_tasks.each do |sub_task|
              new_task.sub_tasks.push sub_task.dup
            end
            task.attachments.each do |attachment|
              file = upload_attachment(attachment)
              new_task.attachments.push file if file.present?
            end
            new_task.workstream_id = new_workstream.id
            new_task.save
          end
          respond_with new_workstream, serializer: WorkstreamSerializer::Base
          PushEventJob.perform_later('workstream-created', current_user, {
            workstream_name: new_workstream[:name],
            tasks_count: new_workstream.tasks.count
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.workstream.created', name: new_workstream[:name])
          })

          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.workstream.created', name: new_workstream[:name])
          })
        end

        def bulk_update_template_task_owners
          data = params[:data]
          return if !data
          OffBoard::ReassignTemplateTasksJob.perform_later(data)
        end

        private

        def workstream_params
          params.permit(:name, :position, :term, :process_type_id, :sort_type).merge(meta: params[:meta], updated_by_id: current_user.id)
        end

        def collection_params
          params.merge!(company_id: current_company.id, sort_order: params[:sort_order], sort_column: params[:sort_column], term: params[:term], onboarding_plan: current_company.onboarding?)
          params.merge!(smart: true) if params[:process_type] == 'Onboarding'
          params
        end

        def paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1 rescue 1
          params.merge(company_id: current_company.id, sort_order: params[:sort_order], sort_column: params[:sort_column], term: params[:term], page: page, per_page: params[:length])
        end
      end
    end
  end
end
