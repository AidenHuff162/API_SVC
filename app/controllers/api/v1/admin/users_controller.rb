module Api
  module V1
    module Admin
      class UsersController < BaseController
        include CustomTableSnapshots
        include ProfilePermissions
        include ADPHandler, IntegrationHandler
        include IntegrationFilter
        include WebhookHandler
        include XeroIntegrationUpdation
        include ManageUserRoles
        include HrisIntegrationsService::Workday::Logs

        require 'devise_token_auth'
        load_and_authorize_resource except: [:index, :create, :update, :paginated]
        authorize_resource only: [:index, :create, :update, :paginated, :create_onboard_custom_snapshots,
         :create_offboard_custom_snapshots, :create_manager_change_custom_snapshots, :reassign_manager_offboard_custom_snapshots, :test_digest_email,
          :bulk_onboard_users]

        before_action only: [:basic, :datatable_paginated, :all_open_activities, :get_job_titles] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
        end
        before_action only: [:get_job_titles] do
          ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, params[:sub_tab])
        end
        before_action only: [:assign_individual_policy, :unassign_policy] do
          PermissionService.new.can_assign_unassign_individual_policy(current_user)
        end
        before_action only: [:unassign_policy] do
          PermissionService.new.can_unassign_individual_policy(params[:id], params[:selected_policy_id])
                 end
        before_action only: [:create_onboard_custom_snapshots, :create_offboard_custom_snapshots, :reassign_manager_offboard_custom_snapshots] do
          if action_name == "create_offboard_custom_snapshots" || action_name == "reassign_manager_offboard_custom_snapshots"
            ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, 'dashboard', 'offboard_snapshots')
          else
            ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, 'dashboard')
          end
        end
        before_action only: [:cancel_offboarding] do
          ::PermissionService.new.can_not_cancel_own_offboarding(current_user, params[:id]) if params[:id].present?
        end
        before_action only: [:create_rehired_user_snapshots] do
          ::PermissionService.new.can_not_manage_own_rehire(current_user, params[:id]) if params[:id].present?
        end

        before_action only: [:update_pending_hire_user] do
          ::PermissionService.new.owner_can_manage(current_user, params[:id]) if params[:id].present?
        end

        before_action only: [:change_onboarding_profile_template] do
          ::PermissionService.new.checkAdminCanViewAndEditProfileTemplate(current_user, params[:id]) if params[:id].present?
        end

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end
        before_action :exclude_admin_users, only: [:fetch_role_users]

        def basic
          collection = UsersCollection.new(collection_params)
          if params[:bulk_onboarding_serializer]
            respond_with collection.results.includes(:team, :location, :profile_image), each_serializer: UserSerializer::BulkOnboarding
          else
            respond_with collection.results.includes(:team, :location, :profile_image), each_serializer: UserSerializer::Basic
          end
        end

        def login_as_user
          if user_signed_in? && current_user.role == 'account_owner'
            user = current_company.users.find_by(id: params[:id])
            current_user = user
            render json: current_user.create_new_auth_token, status: 200
          else
            render json: {message: "Invalid user."}, status: 400
          end
        end

        def create_ghost_user
          User.transaction do
            u = User.new(role: 2, first_name: params[:first_name], last_name: params[:last_name], expires_in: params[:expiration_date].to_date, email: params[:email], state: 'active', company: current_company, current_stage: 'registered', start_date: Date.today, super_user: true)
            u.user_role = current_company.user_roles.find_by(name: 'Ghost Admin')
            u.save!
            UserMailer.ghost_user_password(u, current_user).deliver_now!
          end
        end

        def back_to_admin
          if user_signed_in? && back_to_admin_params[:super_admin_id].present?
            user = current_company.users.find_by(id: back_to_admin_params[:super_admin_id])
            current_user = user
            render json: current_user.create_new_auth_token, status: 200
          end
        end

        def get_managed_users
          collection = UsersCollection.new(collection_params)
          respond_with collection.results.includes(:manager, :location, :profile_image), each_serializer: UserSerializer::LightWithManager
        end

        def bulk_reassing_manager
          manage_reassing_manager_snapshots(params[:data], current_user) if params[:data].present? && (current_user.account_owner? || current_user.is_admin_with_view_and_edit_people_page?)
          head 200
        end

        def autocomplete_user_request
          collection = UsersCollection.new(collection_params).results
          respond_with collection, each_serializer: UserSerializer::PeopleTeamManager
        end

        def group_basic
          collection = UsersCollection.new(collection_params)
          respond_with collection.results, each_serializer: UserSerializer::GroupBasic
        end

        def offboarding_basic
          collection = UsersCollection.new(offboard_basic_params)
          respond_with collection.results.includes(:manager, :buddy, :location), each_serializer: UserSerializer::OffboardingBasic
        end

        def index
          collection = UsersCollection.new(collection_params)
          if params[:multi_select_options].present?
            respond_with collection.results.includes(:location), each_serializer: UserSerializer::MultiselectOptions
          elsif params[:user_id]
            respond_with current_company.users.where(id: params[:user_id]), each_serializer: UserSerializer::HomeLight
          else
            respond_with collection.results.includes(:location), each_serializer: UserSerializer::AutoComplete
          end
        end

        def create
          save_respond_with_form user_params_with_created_by_id
          PushEventJob.perform_later('employee-onboarded', current_user, {
            employee_name: user_params_with_created_by_id[:first_name] + ' ' + user_params_with_created_by_id[:last_name],
            employee_email: user_params_with_created_by_id[:email],
            company: current_company[:name]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.admin_user.created', full_name: current_user.full_name, first_name: user_params_with_created_by_id[:first_name], last_name: user_params_with_created_by_id[:last_name])
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.admin_user.created', full_name: current_user.full_name, first_name: user_params_with_created_by_id[:first_name], last_name: user_params_with_created_by_id[:last_name]),
            attached_users: [current_user.id, @saved_user.id]
          })
        end

        def show
          respond_with @user, serializer: UserSerializer::Full
        end

        def update
          selected_user = current_company.users.find_by(id: user_params[:id])
          if selected_user.workday_id && params[:is_profile_image_updated] && !params[:profile_image]&.dig(:remove_file)
            log_to_wd_teams_channel(selected_user, 'Status: In admin controller to update profile image', 'Workday Bulk Update Logs - Prod')
          end
          selected_user.update!(buddy_id: nil) if params.has_key?(:buddy_id) && !user_params[:buddy_id].present?
          selected_user.update!(manager_id: nil) if params.has_key?(:manager_id) && !user_params[:manager_id].present?
          selected_user.update!(email: '') if params.has_key?(:email) && !user_params[:email].present?
          user = UserForm.new(user_params.except(:role, :user_role_id))
          tempUser = selected_user
          slack_message = nil
          history_description = nil
          if user_params[:division_object].present?
            division_hash = user_params[:division_object]
            tempUser.custom_field_values.find_or_create_by(custom_field_id: division_hash["custom_field_id"]).update_column(:custom_field_option_id, division_hash["id"])
            Rails.cache.delete([division_hash["custom_field_id"], tempUser.id, 'custom_field_values']) if division_hash["custom_field_id"].present? && tempUser.present?
          end
          if user_params[:state] == "active" &&
             ((user_params[:personal_email] && tempUser.personal_email != user_params[:personal_email]) ||
              tempUser.first_name != user_params[:first_name] ||
              tempUser.last_name != user_params[:last_name])
            PushEventJob.perform_later('personal-information-updated', current_user, {
              employee_id: user_params[:id],
              employee_name: "#{user_params[:first_name]} #{ user_params[:last_name]}",
              employee_email: user_params[:email],
              company: current_company[:name]
            })
            slack_message = I18n.t('slack_notifications.admin_user.updated.personal_information', first_name: user_params[:first_name], last_name: user_params[:last_name])
            # history_description = I18n.t('history_notifications.admin_user.updated.personal_information', first_name: user_params[:first_name], last_name: user_params[:last_name])
          elsif user_params[:state] == "active" && user_params[:manager_id] && tempUser[:manager_id] != user_params[:manager_id]
            PushEventJob.perform_later('manager-updated', current_user, {
              employee_id: user_params[:id],
              employee_name: "#{user_params[:first_name]} #{ user_params[:last_name]}",
              employee_email: user_params[:email],
              manager: user_params[:manager_id],
              company: current_company[:name]
            })
            user_params[:manager_terminate_callback] = true
            slack_message = I18n.t('slack_notifications.admin_user.updated.manager', first_name: user_params[:first_name], last_name: user_params[:last_name])
            # history_description = I18n.t('history_notifications.admin_user.updated.manager', first_name: user_params[:first_name], last_name: user_params[:last_name])
          elsif user_params[:state] == "active" &&
             ((user_params[:location_id] && tempUser.location_id != user_params[:location_id]) ||
              (user_params[:title] && tempUser.title != user_params[:title]))
            PushEventJob.perform_later('contact-details-updated', current_user, {
              employee_id: user_params[:id],
              employee_name: "#{user_params[:first_name]} #{ user_params[:last_name]}",
              employee_email: user_params[:email],
              title: user_params[:title],
              company: current_company[:name]
            })
            slack_message = I18n.t('slack_notifications.admin_user.updated.contact_details', first_name: user_params[:first_name], last_name: user_params[:last_name])
            # history_description = I18n.t('history_notifications.admin_user.updated.contact_details', first_name: user_params[:first_name], last_name: user_params[:last_name])
          else
            PushEventJob.perform_later('employee-updated', current_user, {
              employee_id: user_params[:id],
              employee_name: "#{user_params[:first_name]} #{ user_params[:last_name]}",
              employee_email: user_params[:email],
              company: current_company[:name]
            })
            slack_message = I18n.t('slack_notifications.admin_user.updated.profile', first_name: user_params[:first_name] || tempUser.first_name, last_name: user_params[:last_name] || tempUser.last_name)
            # history_description = I18n.t('history_notifications.admin_user.updated.profile', first_name: user_params[:first_name] || tempUser.first_name, last_name: user_params[:last_name] || tempUser.last_name)
          end
          save_respond_with_form user_params_with_created_by_id, params["update_consent"]
          user.record.manager_email() if params[:is_change_manager]
          user.user.reassign_manager_activities(tempUser.manager_id, user.manager_id) if params[:is_change_manager]
          user.user.reassign_buddy_activities(tempUser.buddy_id, user.buddy_id) if params[:is_change_buddy]
          user.user.update_user_existing_manager_docs_cosigner() if params[:update_user_manager_docs_cosigner]

          if user_params[:state] == "inactive"
            slack_message = "Employee *#{user_params[:first_name]} #{user_params[:last_name]}* has been offboarded."
          end

          update_user_emails_to(user, tempUser) if user.onboard_email != tempUser.onboard_email

          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: slack_message
          }) if slack_message.present?

          begin
            send_updates_to_integrations(tempUser, user_params)
            send_updates_to_webhooks(current_company, {event_type: 'profile_changed', attributes: tempUser.attributes, params_data: user_params, profile_update: false})
          rescue Exception => e
          end

          Interactions::HistoryLog::CustomFieldHistoryLog.log(tempUser,user_params,current_user)  if user_params[:state] == "active" && !params["section"]

        end

        def send_updates_to_integrations(user, user_params)
          updated_user = current_company.users.find_by(id: user.id)
          integration_type = current_company.integration_type
          auth_type = current_company.authentication_type

          if current_company.integration_types.include?("bamboo_hr") && updated_user.bamboo_id.present?
            if (user_params[:manager_id] && user.manager_id != user_params[:manager_id]) ||
              (user_params[:title] && user.title != user_params[:title]) ||
              (user_params[:team_id] && user.team_id != user_params[:team_id]) ||
              (user_params[:location_id] && user.location_id != user_params[:location_id])
              ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "Job Information")
            end
            ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "preferred_name") if user_params[:preferred_name] && user.preferred_name != user_params[:preferred_name]
            ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "Employment Status") if user_params[:employee_type] && user.employee_type != user_params[:employee_type]
            ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "personal_email") if user_params[:personal_email] && user.personal_email != user_params[:personal_email]
            ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "last_name") if user_params[:last_name] && user.last_name != user_params[:last_name]
            ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "first_name") if user_params[:first_name] && user.first_name != user_params[:first_name]
            ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "email") if user_params[:email] && user.email != user_params[:email]
            ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "Profile Photo") if user_params[:is_profile_image_updated].present?
            ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "start_date") if user_params[:start_date] && user_params[:start_date].to_date.strftime("%Y-%m-%d") != user.start_date.to_s
          end

          if auth_type == "one_login" && updated_user.one_login_id.present?
            manage_one_login_updates(user, user_params)
          end

          if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| current_company.integration_types.include?(api_name) }.present?
            if user_params[:personal_email] && user.personal_email != user_params[:personal_email]
              update_adp_profile(user.id, "Personal Email", nil, user_params[:personal_email]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
            end
            if user_params[:email] && user.email != user_params[:email]
              update_adp_profile(user.id, 'Email', nil, user_params[:email]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
            end
            if user_params[:preferred_name] && user.preferred_name != user_params[:preferred_name]
              update_adp_profile(user.id, "Preferred Name", nil, user_params[:preferred_name]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
            end
            if user_params[:first_name] && user.first_name != user_params[:first_name]
              update_adp_profile(user.id, "First Name", nil, user_params[:first_name]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
            end
            if user_params[:last_name] && user.last_name != user_params[:last_name]
              update_adp_profile(user.id, "Last Name", nil, user_params[:last_name]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
            end
            if user_params[:title] && user.title != user_params[:title]
              update_adp_profile(user.id, "Job Title", nil, user_params[:title]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
            end
            if user_params[:manager_id] && user.manager_id != user_params[:manager_id]
              update_adp_profile(user.id, 'Manager Id', nil, nil) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
            end
          end

          manage_gsuite_update(user, current_company, params)

          if current_company.can_provision_adfs? && user.active_directory_object_id.present?
            manage_adfs_productivity_update(user, params)
          end

          manage_okta_updates(user, params)

          ::IntegrationsService::UserIntegrationOperationsService.new(user).perform('update', params)
        end

        def paginated
          if !params[:per_page]
            params[:per_page] = current_company.users_count
          end

          collection = UsersCollection.new(collection_params)

          if params[:basic]
            respond_with collection.results, each_serializer: UserSerializer::People, meta: {count: collection.count}, adapter: :json
          elsif params[:permissions]
            respond_with collection.results.order(:id), each_serializer: UserSerializer::Permissions, meta: {count: collection.count}, adapter: :json
          else
            respond_with collection.results, each_serializer: UserSerializer::Dashboard, meta: {count: collection.count}, adapter: :json
          end
        end

        def datatable_paginated
          collection = UsersCollection.new(datatable_paginated_params)
          results = collection.results
          render json: {
              draw: params[:draw].to_i,
              recordsTotal: collection.count,
              recordsFiltered: collection.count,
              data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: UserSerializer::Dashboard)
            }
        end

        def home_group_paginated
          if !params[:per_page]
            params[:per_page] = current_company.users_count
          end

          home_group_params = collection_params
          if current_company.group_for_home == current_company.department
            home_group_params[:custom_field_option_id] = nil
            collection = UsersCollection.new(home_group_params)
            respond_with collection.results, each_serializer: UserSerializer::History, meta: {count: collection.count}, adapter: :json
          else
            home_group_params[:team_id] = nil
            collection = UsersCollection.new(home_group_params)
            respond_with collection.results, each_serializer: UserSerializer::History, meta: {count: collection.count}, adapter: :json
          end
        end

        def all_open_activities
          collection = UsersCollection.new(collection_params)
          users = collection.results
          total_open_activities = 0
          total_overdue_activities = 0
          users.each do |user|
            total_open_activities += user.outstanding_tasks_count
            total_overdue_activities += TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                                                          .where("( (users.current_stage NOT IN (?) AND users.state <> 'inactive') OR ( (current_stage = ?) AND ( (termination_date > ?) OR (outstanding_tasks_count > 0))) )", [User.current_stages[:incomplete], User.current_stages[:departed]], User.current_stages[:departed], 15.days.ago.to_date)
                                                          .where("user_id = ? AND task_user_connections.state = 'in_progress' AND due_date < ?", user.id, Date.today)
                                                          .count
          end
          date = current_company.time.to_date
          render json: {open_activities_count: total_open_activities, overdue_activities_count: total_overdue_activities}, status: 200
        end

        def get_open_documents_count
          overdue_documents = PaperworkRequest.overdue_paperwork_request_count(current_company) + UserDocumentConnection.overdue_upload_requests_count(current_company)
          open_document = PaperworkRequest.open_paperwork_request_count(current_company) + UserDocumentConnection.open_upload_requests_count(current_company)
          pending_approvals_count = CustomTableUserSnapshot.get_pending_approvals_count(current_company)
          pending_custom_section_approvals_count = CustomSectionApproval.get_pending_custom_section_approvals_count(current_company)
          render json: {open_document: open_document, overdue_documents: overdue_documents, pending_approvals_count: pending_approvals_count, pending_custom_section_approvals_count: pending_custom_section_approvals_count }, status: 200
        end


        def get_role_users
          collection = UsersCollection.new(collection_params.merge(user_role_id: params[:user_role_id], exclude_departed: true))
          respond_with collection.results, each_serializer: UserSerializer::Profile, meta: {count: collection.count}, adapter: :json
        end

        def all_open_tasks
          outstanding_tasks_params = collection_params.merge(all_outstanding_tasks_count: true)
          total_open_activities = UsersCollection.new(outstanding_tasks_params).results.to_a.first.outstanding_tasks_count

          total_overdue_activities_params = collection_params.merge(total_overdue_activities_count: true)
          total_overdue_activities = UsersCollection.new(total_overdue_activities_params).results

          render json: {open_activities_count: total_open_activities, overdue_activities_count: total_overdue_activities}, status: 200
        end

        def complete_user_activities
          Interactions::Users::CompleteUserActivities.new(@user).perform
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def get_users_for_permissions
          collection = UsersCollection.new(collection_params)
          respond_with collection.results, each_serializer: UserSerializer::Permissions, meta: {count: collection.count}, adapter: :json
        end

        def bulk_delete
          company = current_company
          curr_user = current_user
          user_ids = params[:user_ids]

          return if user_ids.empty?
          return unless curr_user.role == "account_owner" || curr_user.is_admin_with_view_and_edit_people_page?

          company.users.where(id: user_ids).each do |user|
            user.destroy!
            PushEventJob.perform_later('employee-deleted', curr_user, {
              employee_id: user[:id],
              employee_name: user[:first_name] + ' ' + user[:last_name],
              employee_email: user[:email],
              company: company[:name]
            })
            SlackNotificationJob.perform_later(company.id, {
              username:  curr_user.full_name,
              text: I18n.t("slack_notifications.admin_user.deleted", first_name: user[:first_name], last_name: user[:last_name])
            })
            History.create_history({
              company: company,
              user_id: curr_user.id,
              description: I18n.t("history_notifications.admin_user.deleted", first_name: user[:first_name], last_name: user[:last_name])
            })
          end
          head 200
        end

        def destroy
          @user.update_column(:visibility, false)
          ::Users::DeleteUserJob.perform_async(@user.id, current_user.id, current_company.id)
          head 204
        end

        def send_tasks_email
          SendTasksEmailJob.perform_async(params[:id], params[:task_ids], false)
          owner_ids = TaskUserConnection.joins(task: :workstream).where(user_id: params[:id], task_id: params[:task_ids]).pluck(:owner_id).uniq
          if current_company.send_notification_before_start
            response = { sent_email_count: User.where(id: owner_ids).where.not("current_stage IN (?) OR state = 'inactive'", [User.current_stages[:incomplete], User.current_stages[:departed]]).count }
          else
            response = { sent_email_count: User.where(id: owner_ids).where.not("users.start_date > ?", Date.today).where.not("current_stage IN (?) OR state = 'inactive'", [User.current_stages[:incomplete], User.current_stages[:departed]]).count }
          end
          respond_with response
        end

        def test_digest_email
          today = Date.today.in_time_zone(current_company.time_zone).to_date
          today = (Date.today + 1.week).beginning_of_week(:monday) unless today.monday?
          cutoff_date = today + 6.days
          WeeklyTeamDigestEmailService.new(@user, current_user).trigger_digest_email(today, cutoff_date)
        end

        def resend_invitation
          user = current_company.users.find_by_id(params[:id]) if params[:id]
          Interactions::Users::SendInvite.new(user.id).perform if !user.inactive?
          head 200
        end

        def get_job_titles
          results = Rails.cache.fetch("#{current_company.id}/job_titles", expires_in: 2.days) do
            UsersCollection.new(user_job_titles_params).results
          end
          render json: {data: results}, status: 200
        end

        def invite_user
          user_data, sandbox_invite = user_params, params[:sandbox_invite] == "true"
          user_data[:state] = 'active'
          user_data[:current_stage] = 'registered'
          form = UserForm.new(user_data)
          form.save!
          user = form.record

          # handles assign role feature for sandbox invite-dialog
          assign_user_role(user.id, params[:role_id]) if sandbox_invite
          Interactions::Users::SendInvite.new(user.id, user_data[:invited_employee], true, sandbox_invite, current_user.full_name).perform if user
        end

        def invite_users
          BulkInvitesJob.perform_async(params[:user_ids], current_company.id) if current_user.role == "account_owner" || current_user.is_admin_with_view_and_edit_people_page?
        end

        def offboard_user
          user_form = UserForm.new(user_params)
          user_form.save!
          user_task_params = params.to_h[:tasks]
          user = user_form.user.reload
          SendUserEmailsJob.perform_later(user_form.id, 'offboarding', params[:send_incomplete_emails], params[:schedule_email_ids])
          if user_task_params
            OffBoard::AssignUserTasksJob.perform_async(user_form.id, user_task_params, current_user.id)
          else
            user_form.record.offboard_user
          end

          CustomAlerts::TerminatedCustomAlertJob.perform_later(current_company.id, current_user.id, user_form.id)

          respond_with user, serializer: UserSerializer::OffboardingBasic
          begin
            if user.current_stage == "offboarding"
              SlackNotificationJob.perform_later(current_company.id, {
                username:  current_user.full_name,
                text: I18n.t("slack_notifications.admin_user.offboarding", full_name: user.full_name)
              })
              History.create_history({
                company: current_company,
                user_id: current_user.id,
                description: I18n.t("history_notifications.admin_user.offboarding", full_name: user.full_name),
                attached_users: [user.id]
              })

            elsif user.current_stage == "departed"
              SlackNotificationJob.perform_later(current_company.id, {
                username:  current_user.full_name,
                text: I18n.t("slack_notifications.admin_user.offboarded", full_name: user.full_name)
              })
              History.create_history({
                company: current_company,
                user_id: current_user.id,
                description: I18n.t("history_notifications.admin_user.offboarded", full_name: user.full_name),
                attached_users: [user.id]
              })
              ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(user_form.record, 'Offboarded') if user_form.record && user_form.record.bamboo_id.present?
              ::HrisIntegrations::Workday::TerminateUserInWorkdayJob.perform_later(user_form.record.id) if user_form.record.workday_id.present?
            end
            user.reload
            if user && current_user
              ::CustomTables::CustomTableSnapshotManagement.new.offboarding_management(current_user, user, current_company, params[:custom_fields_data], params[:lde_data])
              user_data = params[:data]
              ::CustomTables::CustomTableSnapshotManagement.new.reassigning_manager_offboard_custom_snapshots(current_user, user_data, current_company) if user_data.present?
              ::CustomTables::CustomTableSnapshotManagement.new.change_manager_custom_snapshot(current_user, user.reload, current_company) if true?(user_params[:is_manager_changed])
              SmartAssignmentIndividualPaperworkRequestJob.perform_later(user.id, current_company.id, current_user.id) if should_assign_offboarding_docs?(user)
            end
          send_updates_to_webhooks(current_company, {event_type: 'offboarding', type: 'offboarding', stage: 'started', triggered_for: user.id, triggered_by: current_user.id, user_id: user.id}) unless (Date.today.to_s > user.termination_date.to_s)
          rescue Exception => e
          end
        end

        def update_task_date
          if update_task_date_params[:type] != 'start_date'
            UpdateTaskDueDateJob.perform_later(update_task_date_params[:id], true, user_params[:_update_termination_activities], nil,
                                               false)
          end
          render body: Sapling::Application::EMPTY_BODY, status: 200
        end

        def update_termination_date
          termination_date = current_company.users.find(user_params[:id]).termination_date
          form = UserForm.new(user_params)
          form.save!
          respond_with form.user, serializer: UserSerializer::Dashboard
        end

        def activity_owners
          if params[:type] == "document"
            collection = PaperworkRequestsCollection.new(collection_params)
            respond_with collection.results, each_serializer: PaperworkRequestSerializer::ActivityOwner, activity_id: params[:activity_id], type: params[:type], adapter: :json
          else
            collection = UsersCollection.new(collection_params)
            respond_with collection.results, each_serializer: UserSerializer::ActivityOwner, activity_id: params[:activity_id], type: params[:type], adapter: :json
          end
        end

        def set_manager
          user = current_company.users.find_by(id: params[:id])
          old_manager_id = user.manager_id if user.manager_id.present?
          user.manager_id = params[:manager]
          user.save!
          user.manager_email()
          if current_company.try(:is_using_custom_table).present?
            update_custom_snapshot_manager(user, current_user)
          end
          user.reassign_manager_activities(old_manager_id, params[:manager])  if old_manager_id.present? && params[:re_assign_activities]
          send_updates_to_integrations(user, params.merge!(manager_id: old_manager_id))
          respond_with user, serializer: UserSerializer::Full
        end

        def update_pending_hire_user
          changed_info = @user.pending_hire.changed_info
          if changed_info.present?
            if current_company.is_using_custom_table
              ::CustomTables::CustomTableSnapshotManagement.new.pending_hire_management(current_user, @user, current_company, @user.pending_hire) if @user.present? && current_user.present?
            else
              @user.set_fields_by_pending_hire(changed_info, false)
            end
            @user.pending_hire.destroy
          end
        end

        def cancel_offboarding
          create_general_logging(current_company, "Cancel Offboarding-Rehire", params.to_hash)
          if params[:id].present?
            user = current_company.users.find_by(id: params[:id])
            if params[:is_rehired].present?
              user.update_column(:is_rehired, true)
            else
              ::CustomTables::CustomTableSnapshotManagement.new.delete_terminated_custom_snapshot(user, current_user) if current_company&.custom_tables.present? && user.departed?.blank?
               send_updates_to_webhooks(current_company, {event_type: 'offboarding', type: 'offboarding', stage: 'cancelled', triggered_for: user.id, triggered_by: current_user.id, user_id: user.id})
            end
            user.cancel_offboarding

            ::IntegrationsService::UserIntegrationOperationsService.new(user).perform('reactivate')
          end
          head 200
        end

        def fetch_role_users
          collection = UsersCollection.new(collection_params.merge(exclude_departed: true))
          respond_with collection.results, each_serializer: UserSerializer::Profile
        end

        def restore_user_snapshots
          if current_company.try(:is_using_custom_table).present?
            user = current_company.users.find(params[:id])
            restore_previous_snapshot_values user
            head 204
          end
        end

        def create_rehired_user_snapshots
          if current_company&.custom_tables.present?
            user = current_company.users.find_by(id: params[:id])
            if user.present?
              ::CustomTables::CustomTableSnapshotManagement.new.rehiring_management(user, current_user)
            end
          end
          head 200
        end

        def assign_individual_policy
          response = PTO::AssignPolicy::IndividualPolicy.new(params[:effective_date], params[:selected_policy], params[:id], params[:starting_balance], current_company.id).perform
          if response.class.name == 'AssignedPtoPolicy'
            respond_with response.pto_policy, serializer: PtoPolicySerializer::Basic, object: response.user, manually_assigned: true
          elsif response.class.name == 'UnassignedPtoPolicy'
            response_object = {}
            response_object[:assign_later] = true
            respond_with response_object
          end
        end

        def unassign_policy
          response = PTO::UnassignPolicy::IndividualPolicy.new(params[:selected_policy_id], params[:id]).perform
          if response[:status] == 200
            respond_with response
          else
            response[:status] = 500
            respond_with response
          end
        end

        def create_onboard_custom_snapshots
          user = current_company.users.find_by(id: user_params[:id])
          ::CustomTables::CustomTableSnapshotManagement.new.onboarding_management(current_user, user, current_company) if user.present? && current_user.present?
          head 200
        end

        def create_offboard_custom_snapshots
          user = current_company.users.find_by(id: user_params[:user_id])
          ::CustomTables::CustomTableSnapshotManagement.new.offboarding_management(current_user, user, current_company, params[:custom_fields_data], params[:lde_data]) if user.present? && current_user.present?
          head 200
        end

        def create_manager_change_custom_snapshots
          user = current_company.users.find_by(id: user_params[:id])
          ::CustomTables::CustomTableSnapshotManagement.new.change_manager_custom_snapshot(current_user, user, current_company) if user.present? && current_user.present?
          head 200
        end

        def reassign_manager_offboard_custom_snapshots
          user_data = params[:data]
          ::CustomTables::CustomTableSnapshotManagement.new.reassigning_manager_offboard_custom_snapshots(current_user, user_data, current_company) if user_data.present?
          head 200
        end

        def bulk_update_managers
          OffBoard::ReassignManagersJob.perform_later(params[:data], params[:notify_new_managers], current_company) if params[:data]
          head 200
        end

        def send_onboarding_emails
          SendUserEmailsJob.perform_later(params[:id], 'onboarding', params[:send_incomplete_emails], nil, params[:profile_template_id], false , draft_tasks_params, current_company.id)
          SmartAssignmentIndividualPaperworkRequestJob.perform_later(params[:id], current_company.id, current_user.id)
          send_updates_to_webhooks(current_company, {event_type: 'onboarding', type: 'onboarding', stage: 'started', triggered_for: params[:id], triggered_by: current_user.id, user_id: params[:id]})
        end

        def update_user_emails
          UpdateScheduledEmailsJob.perform_later(current_company.id, params[:id], params[:type])
          head 200
        end

        def scheduled_email_count
          user = current_company.users.find_by(id: params[:id])
          scheduled_email_counts = user.get_scheduled_email_count(params[:type]) if params[:type].present?

          render json: scheduled_email_counts.to_json, status: 200
        end

        def bulk_onboard_users
          # params users, template_ids, workstream_count, tasks, custom_sections, custom_tables, onboard_email, provision_accounts
          pending_hire_ids = params.to_h['pending_hires'].pluck('id')
          current_company.pending_hires.where(id: pending_hire_ids).update_all(state: 'inactive')
          BulkOnboardUsersJob.perform_async(params.to_h, current_company.id, current_user.id)
          head 200
        end

        def check_email_uniqueness
          # {user id, email, personal_email}
          emails_unique = true
          company_email_taken = false
          personal_email_taken = false
          duplicate_email = nil
          all_emails = []
          params[:emails].try(:each) do |user_emails|
            emails = user_emails[1,2]
            company_email = user_emails[1]
            personal_email = user_emails[2]
            all_emails = all_emails.concat(emails)
            if user_emails[0] && user_emails[0] != 0
              if current_company.users.where("((email IS NOT NULL AND email = ?) OR (personal_email IS NOT NULL AND personal_email = ?)) AND id != ?", company_email, company_email, user_emails[0]).count > 0
                company_email_taken = true
                duplicate_email = company_email
                break
              end
              if current_company.users.where("((email IS NOT NULL AND email = ?) OR (personal_email IS NOT NULL AND personal_email = ?)) AND id != ?", personal_email, personal_email, user_emails[0]).count > 0
                personal_email_taken = true
                duplicate_email = personal_email
                break
              end
            else
              if current_company.users.where("(email IS NOT NULL AND email = ?) OR (personal_email IS NOT NULL AND personal_email = ?)", company_email, company_email).count > 0
                company_email_taken = true
                duplicate_email = company_email
                break
              end
              if current_company.users.where("(email IS NOT NULL AND email = ?) OR (personal_email IS NOT NULL AND personal_email = ?)", personal_email, personal_email).count > 0
                personal_email_taken = true
                duplicate_email = personal_email
                break
              end
            end
          end
          if company_email_taken || personal_email_taken || all_emails.length != all_emails.uniq.length
            message = "Company email address already taken: #{duplicate_email}" if company_email_taken
            message = "Personal email address already taken: #{duplicate_email}" if personal_email_taken
            message = "Multiple new hires have the same company or personal email address." if all_emails.length != all_emails.uniq.length
            render json: { status: '422', message: message }
          else
            head 200
          end
        end

        def send_due_documents_email
          SendDueDocumentsEmailJob.perform_later(params[:request_ids], params[:type], params[:is_from_preview_panel], current_company)
        end

        def import_users_data
          args = { 'company_id'=>current_company.id, 'current_user_id'=> current_user.id, 'upload_date'=> current_company.time.to_date.to_s }
          ImportData::ImportDataJob.perform_async(params.to_h, args)
          head 200
        end

        def change_onboarding_profile_template
          user = current_company.users.find_by(id: params[:id])
          removed_field_ids = user.change_onboarding_profile_template(params[:new_template_id], params[:remove_existing_values])
          render json: { status: '200', removed_field_ids: removed_field_ids }
        end

        def bulk_assign_onboarding_template
          if params[:template_id].present?
            BulkAssignment::ProfileTemplate::Assign.perform_async(params.to_h.merge(company_id: current_company.id))
            render json: { status: '200', template_assigned: 'true' }
          else
            render json: {message: "Invalid Template"}, status: 400
          end
        end

        def bulk_update
          updated = false
          if bulk_update_params[:users].present? && current_company.present?
            hires = current_company.users.where(id: bulk_update_params[:users])
            hires.update_all(location_id:bulk_update_params[:location_id] ,
              team_id: bulk_update_params[:team_id])
            hires.each do |user|
              user.set_employee_type_field_option(bulk_update_params[:employment_status_id])
              params[:custom_groups].each do |custom_field_id, option_id|
                user.set_custom_group_field_option(custom_field_id, option_id.first)
              end if params[:custom_groups]
            end

            updated = true
          end

          render json: {updated: updated}, status: 200
        end

        def pending_hire_draft_documents
          if params[:id]
            pending_hire_draft_documents = PaperworkRequest.pending_hire_draft_paperwork_requests(@user) + UserDocumentConnection.pending_hire_draft_user_document_connections(@user)
          else
            pending_hire_draft_documents = []
          end
          render json: pending_hire_draft_documents, status: 200
        end

        def user_termination_types
          respond_with User.termination_types.keys
        end

        private

        def save_respond_with_form params, update_consent=false
          form = UserForm.new(params)
          if params.has_key?(:team_id) && params[:team_id].nil? && params[:team_id] != form.user.team_id
            form.user.team_id =  nil
            form.team_id =  nil
          end
          if params.has_key?(:location_id) && params[:location_id].nil? && params[:location_id] != form.user.location_id
            form.user.location_id =  nil
            form.location_id =  nil
          end
          if params.has_key?(:manager_id) || params.has_key?(:manager)
            manager_id = params[:manager][:id] if params[:manager]
            manager_id = params[:manager_id] if params[:manager_id]
            if manager_id.nil? && manager_id != form.user.manager_id
              form.user.manager_id = nil
              form.manager_id = nil
            end
          end
          if params.has_key?(:smart_assignment)
            smart_assignment = params[:smart_assignment]
            if smart_assignment
              form.user.smart_assignment = smart_assignment
              form.smart_assignment = smart_assignment
            end
          end
          user = User.find_by_id(form.user.id)
          if user
            old_start_date = user.start_date
            if old_start_date != form.start_date && update_consent == "true"
              form.update_task_dates = true
            else
              form.update_task_dates = false
            end
          else
            form.update_task_dates = false
          end
          form.save!
          @saved_user = form.user
          @saved_user.update_pending_hire(params) if params[:pending_hire_id].present?
          @saved_user.update(password: 'Simpl3BILLPa4!') if %w[billcomsandbox billcomsandbox2].include?(current_company.subdomain)
          message = nil
          if params[:profile_image]&.dig(:remove_file)
            if current_user != @saved_user
              message = 'history_notifications.admin_user.updated.deleted'
            end
            @saved_user&.profile_image&.destroy
            @saved_user&.reload
          else
            message = 'history_notifications.admin_user.updated.created'
            @saved_user&.profile_image&.reload
          end
          History.create_history({
            company: current_company,
            user_id: @saved_user.id,
            description: I18n.t(message, full_name: current_user.full_name, full_name_temp: @saved_user.full_name)
          })if message.present?
          respond_with @saved_user, serializer: UserSerializer::Full, scope: {profile_permissions: get_profile_permissions(@saved_user)}
        end

        def user_params
          params.merge(company_id: current_company.id)
        end

        def update_task_date_params
          params.permit(:id, :type)
        end

        def user_job_titles_params
          user_params.merge(pluck_job_titles: true)
        end

        def collection_params
          params.merge(company_id: current_company.id)
        end

        def offboard_basic_params
          params.merge(company_id: current_company.id).merge(not_offboarded: true, offboarding_employees_search: true, current_user: current_user)
        end

        def user_params_with_created_by_id
          exclude_ids =  current_company.pending_hires.where.not(user_id: nil).pluck(:user_id)
          if params.has_key?(:team_id)
            params.merge(company_id: current_company.id, created_by_id: current_user.id, exclude_ids: exclude_ids, team_id: params[:team_id])
          else
            params.merge(company_id: current_company.id, created_by_id: current_user.id, exclude_ids: exclude_ids)
          end
        end

        def datatable_paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1

          params.merge(
            company_id: current_company.id,
            page: page,
            per_page: params[:length].to_i,
            order_column: params[:sort_column],
            order_in: params[:sort_order],
            term: params[:term].blank? ? nil : params[:term],
            profile_template_id: params[:profile_template_id]
          )
        end

        def exclude_admin_users
          if current_user.user_role.role_type == "admin"
            exclude_ids = [current_user.id] + (current_company.user_roles.find_by(role_type: UserRole.role_types["super_admin"]).users.pluck(:id) )
            params.merge!(exclude_ids: exclude_ids)
          end
        end

        def bulk_update_params
          params.permit(:team_id, :location_id, :employment_status_id, users: [])
        end

        def update_user_emails_to user, tempUser
          user_to = []
          if !user.onboard_email
            user.email.present? ? user_to.push(user.email) : user_to.push(user.personal_email)
          elsif user.onboard_email == 'personal'
            user_to.push user.personal_email
          elsif user.onboard_email == 'company'
            user_to.push user.email
          elsif user.onboard_email == 'both'
            user_to.push(user.email) if user.email
            user_to.push user.personal_email
          end
          tempUser.user_emails.where(email_status: UserEmail::statuses[:incomplete], email_type: "invitation").update(to: user_to) if tempUser.user_emails.present?
        end

        def draft_tasks_params
          params.to_h[:assigned_draft_tasks] || []
        end

        def back_to_admin_params
          params.permit(:super_admin_id)
        end

        def true?(obj)
          obj.to_s.downcase == "true"
        end

        def should_assign_offboarding_docs?(user)
          (!current_company.is_using_custom_table? || (user.termination_date && (Date.today < user.termination_date))) &&
            (user.user_document_connections.draft_connections || user.paperwork_requests.draft_requests)
        end

      end
    end
  end
end
