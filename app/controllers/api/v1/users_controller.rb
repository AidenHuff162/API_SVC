module Api
  module V1
    class UsersController < BaseController
      require 'rubygems'
      require 'zip'
      require 'open-uri'

      include ProfilePermissions
      include ADPHandler, IntegrationHandler
      include IntegrationFilter
      include WebhookHandler
      include XeroIntegrationUpdation
      include CustomTableSnapshots
      include CustomSectionApprovalHandler
      include PasswordStrength
      include HrisIntegrationsService::Workday::Logs

      skip_before_action :require_company!, only: [:basic_search, :get_parent_ids], raise: false
      skip_before_action :authenticate_user!, only: [:basic_search, :get_parent_ids], raise: false
      skip_before_action :verify_current_user_in_current_company!, only: [:basic_search, :get_parent_ids], raise: false

      before_action only: [:manager_form_snapshot_creation] do
        ::PermissionService.new.can_access_manager_form(current_user, params[:id]) if params[:id]
      end

      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 204
      end

      load_and_authorize_resource
      skip_authorize_resource only: [:mentioned_users, :basic_search, :get_parent_ids]

      def index
        collection = UsersCollection.new(collection_params)
        respond_with collection.results, each_serializer: UserSerializer::Short
      end

      def mentions_index
        collection = UsersCollection.new(collection_params.merge(check_user_state: true)).results
        respond_with collection, each_serializer: UserSerializer::Mention
      end

      def mentioned_users
        users = current_company.users.where(id: mentioned_users_params[:users])
        respond_with users, each_serializer: UserSerializer::Mention
      end

      def basic_search
        collection = UsersCollection.new(collection_params)
        respond_with collection.results.includes(:profile_image), each_serializer: UserSerializer::GroupBasic
      end

      def user_algolia_mock
        if Rails.env.test? || Rails.env.development?
          respond_with current_company.users.not_incomplete, each_serializer: UserSerializer::AlgoliaMock
        else
          head :ok
        end
      end

      def verify_password_strength
        password_strength_checker(params[:password])
      end

      def basic
        collection = UsersCollection.new(collection_params).results
        respond_with collection.includes(:team, :location, :profile_image), each_serializer: UserSerializer::Basic
      end

      def show
        if params[:permission_light]
          respond_with @user, serializer: UserSerializer::PermissionsLight
        else
          respond_with @user, serializer: UserSerializer::Full, include: '**'
        end
      end

      def home_user
        if params[:light]
          respond_with @user, serializer: UserSerializer::HomeLight
        elsif current_user.role == 'account_owner' || (PermissionService.new.fetch_accessable_custom_field_sections(current_company, current_user, @user)).include?(0)
          if params[:profile_page]
            @user.change_bulk_requested_attributes if params[:approval_profile_page]
            respond_with @user,
              serializer: UserSerializer::HomeProfilePage,
              scope: {profile_permissions: get_profile_permissions(@user),
              current_user: current_user}, approval_profile_page: params[:approval_profile_page], include: '**'
          elsif params[:task_page]
            respond_with @user, serializer: UserSerializer::HomeTaskPage
          elsif params[:document_page]
            respond_with @user, serializer: UserSerializer::HomeDocumentPage
          elsif params[:role_page]
            respond_with @user, serializer: UserSerializer::HomeRolePage, include: '**'
          elsif params[:calendar_page]
            respond_with @user, serializer: UserSerializer::HomeCalendarPage
          elsif params[:manager_form] || params[:include_onboarding_template]
            respond_with @user, serializer: UserSerializer::Home, scope: { include_onboarding_template: true, include_pto_policies: true, current_user: current_user }
          elsif params[:updates_page]
            respond_with @user, serializer: UserSerializer::HomeUpdatesPage, scope: { include_pto_policies: true }
          else
            respond_with @user, serializer: UserSerializer::Home, scope: { include_pto_policies: true, current_user: current_user }
          end
        else
          if params[:profile_page]
            @user.change_bulk_requested_attributes if params[:approval_profile_page]
            respond_with @user,
              serializer: UserSerializer::Permitted,
              scope: {profile_permissions: get_profile_permissions(@user),
              current_user: current_user}, approval_profile_page: params[:approval_profile_page]
          elsif params[:task_page] || params[:document_page] || params[:role_page] || params[:calendar_page]
            respond_with @user, serializer: UserSerializer::Permitted, scope: { current_user: current_user, include_onboarding_template: true }
          elsif params[:manager_form] || params[:include_onboarding_template]
            respond_with @user, serializer: UserSerializer::Home, scope: { include_onboarding_template: true, include_pto_policies: true, current_user: current_user }
          else
            respond_with @user, serializer: UserSerializer::Permitted, scope: { include_pto_policies: true, current_user: current_user }
          end
        end
      end

      def get_secure_algoli_key
        valid_until = (Time.now + 10.hours).to_i
        filters = "company_id= #{current_user.company_id}"
        if current_user.employee?
          filters += " AND start_date <= #{Time.now.utc.to_i} AND state = 0"
        end
        public_key = Algolia.generate_secured_api_key(ENV['ALGOLIA_SEARCH_KEY'], { filters: filters, validUntil: valid_until})
        render json: { key:  public_key }, status: 200
      end

      def user_with_pending_ptos
        respond_with @user, serializer: UserSerializer::PeoplePage , scope: {'pto_request': true, current_user: current_user}
      end

      def user_with_pto_policies
        respond_with @user, serializer: UserSerializer::HomeTimeOffPage, scope: { include_pto_policies: true }
      end

      def basic_info
        respond_with @user, serializer: UserSerializer::UserPilotInformation
      end

      def email_availibility
        user_name = params[:username]
        complete_email = "#{user_name}@#{current_company.provisioning_integration_url}"
        email_exists = current_company.users.unscoped.pluck(:email).compact.include? complete_email
        render json: { email_exists:  email_exists }, status: 200
      end

      def create_requested_fields_for_employee_approval
        section_id, fields = prepare_fields_for_cs_approval(params.to_h, params[:id], true, 'users')
        return unless section_id.present?
        @user.change_requested_attributes(section_id)
        render json: @user, serializer: UserSerializer::FullWithApproval, profile_permissions: get_profile_permissions(@user), custom_section_id: section_id, data: fields
      end

      def update
        tempUser = current_company.users.find_by_id(params[:id])
        if tempUser.workday_id && params[:is_profile_image_updated] && !params[:profile_image]&.dig(:remove_file)
          log_to_wd_teams_channel(tempUser, 'Status: In user controller to update profile image', 'Workday Bulk Update Logs - Prod')
        end
        params[:email] = tempUser.email unless is_valid_email_update?(tempUser)
        tempUser.update!(manager_id: nil) if params.has_key?(:manager_id) && !params[:manager_id].present?
        if params[:preboard]
          params[:buddy_id] = tempUser.buddy_id 
        elsif params.has_key?(:buddy_id) && !params[:buddy_id].present?
          tempUser.update!(buddy_id: nil)
        end
        user = UserForm.new(params.except(:role, :user_role_id))
        slack_message = nil
        history_description = nil

        if params[:state] == "active" &&
           (tempUser.personal_email != params[:personal_email] ||
            tempUser.first_name != params[:first_name] ||
            tempUser.last_name != params[:last_name])
          PushEventJob.perform_later('personal-information-updated', current_user, {
            employee_id: params[:id],
            employee_name: "#{params[:first_name]} #{params[:last_name]}",
            employee_email: params[:email],
            company: current_company[:name]
          })
          slack_message = I18n.t("slack_notifications.user.updated.personal_information", first_name: params[:first_name], last_name: params[:last_name])
        elsif params[:state] == "active" && tempUser[:manager_id] != params[:manager_id]
          PushEventJob.perform_later('manager-updated', current_user, {
            employee_id: params[:id],
            employee_name: "#{params[:first_name]} #{params[:last_name]}",
            employee_email: params[:email],
            manager: params[:manager_id],
            company: current_company[:name]
          })
          user.user.manager_terminate_callback = true
          slack_message = I18n.t("slack_notifications.user.updated.manager", first_name: params[:first_name], last_name: params[:last_name])
        elsif params[:state] == "active" &&
           (tempUser.location_id != params[:location_id] ||
            tempUser.title != params[:title])
          PushEventJob.perform_later('contact-details-updated', current_user, {
            employee_id: params[:id],
            employee_name: "#{params[:first_name]} #{params[:last_name]}",
            employee_email: params[:email],
            title: params[:title],
            company: current_company[:name]
          })
          slack_message = I18n.t("slack_notifications.user.updated.contact_details", first_name: params[:first_name], last_name: params[:last_name])
        elsif params[:id].present? && params[:first_name].present? && params[:last_name].present? && params[:email].present?
          PushEventJob.perform_later('employee-updated', current_user, {
            employee_id: params[:id],
            employee_name: "#{params[:first_name]} #{params[:last_name]}",
            employee_email: params[:email],
            company: current_company[:name]
          })
          slack_message = I18n.t("slack_notifications.user.updated.profile", first_name: params[:first_name], last_name: params[:last_name])
        end
        SlackNotificationJob.perform_later(current_company.id, {
          username: current_user.full_name,
          text: slack_message
        }) if slack_message.present?

        user.user.reassign_manager_activities(tempUser.manager_id, user.manager_id) if params[:is_change_manager]
        user.user.reassign_buddy_activities(tempUser.buddy_id, user.buddy_id) if params[:is_change_buddy]
        user.fields_last_modified_at = Date.today
        user.save!
        if user.manager_id && user.manager_id != tempUser.manager_id
          user.record.manager_email()
        end
        current_user.reload

        Interactions::HistoryLog::CustomFieldHistoryLog.log(tempUser,params,current_user)  if !params["section"] && params["state"] == "active"
        begin
          send_updates_to_integrations(tempUser, params)
          send_updates_to_webhooks(current_company, {event_type: 'profile_changed', attributes: tempUser.attributes, params_data: params, profile_update: false})
        rescue Exception => e
        end
        message = nil
        if params[:profile_image]&.dig(:remove_file)
          if current_user == tempUser
            message = 'history_notifications.user.updated.deleted'
          end
          user.record&.profile_image&.destroy
          user.record&.reload
        else
          message = 'history_notifications.user.updated.created'
          user.record&.profile_image&.reload
        end

        History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t(message, full_name: current_user.full_name)
          })if message.present?

        if params[:preboard]
          render json: user.record,
            serializer: UserSerializer::PreboardFull,
            profile_permissions: get_profile_permissions(user.record)
        else
          render json: user.record,
            serializer: UserSerializer::Full,
            profile_permissions: get_profile_permissions(user.record)
        end
      end

      def paginated
        collection = UsersCollection.new(collection_params)
        serialize_with =  if params[:basic]
                            UserSerializer::People
                          elsif params[:new_arrivals]
                            UserSerializer::NewArrival
                          elsif params[:from_preboard]
                            UserSerializer::PreboardTeamTab
                          else
                            UserSerializer::Dashboard
                          end
        respond_with collection.results, each_serializer: serialize_with, meta: {count: collection.count}, adapter: :json
      end

      def people_paginated_count
        collection = UsersCollection.new(collection_params.merge!(count: true))
        render json: {totalPeople: collection.results}
      end

      def total_active_count
        collection = UsersCollection.new(collection_params.merge!(state: 'active', count: true))
        render json: {activePeople: collection.results}
      end

      def dashboard_people_count
        dashboard_params = params
        onboard_params = JSON.parse dashboard_params[:onboard_params]
        offboard_params = JSON.parse dashboard_params[:offboard_params]
        onboard_params = onboard_params.map {|k, v| [k.to_sym, v] }.to_h
        offboard_params = offboard_params.map {|k, v| [k.to_sym, v] }.to_h
        onboard_collection = UsersCollection.new(onboard_params)
        offboard_collection = UsersCollection.new(offboard_params)
        render json: {onboard_count: onboard_collection.results, offboard_count: offboard_collection.results}, status: 200
      end

      def activities_count
        collection = UsersCollection.new(collection_params)
        users = collection.results
        prev_open_activities = 0
        total_open_activities = 0
        open_activities_user_count = 0
        overdue_task_count = nil
        overdue_task_count = TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id").where("( (users.current_stage NOT IN (?) AND users.state <> 'inactive') OR ( (current_stage = ?) AND ( (termination_date > ?) OR (outstanding_tasks_count > 0 OR (incomplete_paperwork_count + incomplete_upload_request_count) > 0))) )", [User.current_stages[:incomplete], User.current_stages[:departed]], User.current_stages[:departed], 15.days.ago.to_date)
                                                      .where("user_id IN (?) AND task_user_connections.state = 'in_progress' AND due_date < ?", users.pluck(:id), Date.today).group(:user_id).count
        overdue_activities_count = overdue_task_count.present? ? overdue_task_count.values.sum : 0
        overdue_users_count = overdue_task_count.present? ? overdue_task_count.keys.length : 0

        outstanding_task_user_with_count = TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id AND users.state <> 'inactive'")
        .where("users.current_stage NOT IN (?)", [User.current_stages[:incomplete], User.current_stages[:departed]]).where("task_user_connections.state = 'in_progress'").where("task_user_connections.user_id IN (?)",users.ids).group(:user_id).count

        total_document_tasks = users.sum("incomplete_paperwork_count + incomplete_upload_request_count + co_signer_paperwork_count")
        total_document_tasks_users = users.where("incomplete_paperwork_count > 0 OR incomplete_upload_request_count > 0 OR co_signer_paperwork_count > 0").group(:id).pluck(:id)

        total_open_activities = total_document_tasks + users.sum('outstanding_tasks_count')

        total_users_array = outstanding_task_user_with_count.keys | total_document_tasks_users
        open_activities_user_count = total_users_array.length

        render json: {
            open_activities_count: total_open_activities,
            open_activities_user_count: open_activities_user_count,
            overdue_activities_count: overdue_activities_count,
            overdue_activities_user_count: overdue_users_count
          }, status: 200
      end

      def get_my_activities_count
        user = current_company.users.find_by_id(params[:id])

        if PermissionService.new.canAccessAssignedDocumentsCount(current_user, params[:id])
          documents_count = user.incomplete_upload_request_count + user.incomplete_paperwork_count + user.co_signer_paperwork_count
        else
          documents_count = 0
        end

        if PermissionService.new.canAccessAssignedTasksCount(current_user, params[:id])
          if user.id == current_user.id || (!user.onboarding? && user.state == 'active')
            active_tasks_count = TaskUserConnectionsCollection.new(task_owner_count_params.merge(owner_id: user.id)).results
            overdue_tasks_count = TaskUserConnectionsCollection.new(overdue_task_owner_count_params.merge(owner_id: user.id)).results
          else
            overdue_task_params = overdue_task_count_params.merge(user_id: user.id)
            task_params = task_count_params.merge(user_id: user.id)
            active_tasks_count = TaskUserConnectionsCollection.new(task_params).results
            overdue_tasks_count = TaskUserConnectionsCollection.new(overdue_task_params).results
          end
        else
          active_tasks_count = overdue_tasks_count = 0
        end

        leave_requests_count = User.pto_requests_pending_approval_count(user.id)
        render json: {active_tasks_count: active_tasks_count, documents_count: documents_count, overdue_tasks_count: overdue_tasks_count, leave_requests_count: leave_requests_count}, status: 200
      end

      def get_team_activities_count
        incomplete_activities_count = 0
        manager = current_company.users.find_by_id(params[:id])
        team_members = manager.managed_users
        team_members.each do |user|
          incomplete_activities_count += TaskUserConnection.incomplete_task_count(user.id)
          incomplete_activities_count += PaperworkRequest.incomplete_paperworks(user.id)
          incomplete_activities_count += user.incomplete_upload_request_count
        end
        render json: {incomplete_activities_count: incomplete_activities_count}, status: 200
      end

      def people_paginated
        collection = UsersCollection.new people_paginated_params
        if params[:people]
          results = collection.results.includes(:location, :team)
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.count,
            recordsFiltered: collection.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: UserSerializer::PeoplePage, scope: {'pto_request': false, current_user: current_user, people_page: params[:people_page]})
          }
        elsif params[:team]
          results = collection.results.includes(:pto_requests)
          collection_count = collection.count
          if params[:prioritize_incomplete_form_by_manager].present?
            collection_count = collection.count.values.count
          end
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection_count,
            recordsFiltered: collection_count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: UserSerializer::Team)
          }
        elsif params[:integration_name]
          results = collection.results
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.count,
            recordsFiltered: collection.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: UserSerializer::Basic)
          }
        end
      end

      def home_group_paginated
        params[:per_page] = current_company.users_count if !params[:per_page]
        home_group_params = collection_params
        nil_attr = current_company.group_for_home == current_company.department ? :custom_field_option_id : :team_id
        home_group_params[nil_attr] = nil
        collection = UsersCollection.new(home_group_params)
        serialize_with = params[:from_preboard] ? UserSerializer::PreboardTeamTab : UserSerializer::People
        respond_with collection.results.includes(:profile, :manager), each_serializer: serialize_with, meta: {count: collection.count}, adapter: :json
      end

      def send_updates_to_integrations(user, params)
        updated_user = current_company.users.find_by_id(user.id)
        integration_type = current_company.integration_type
        auth_type = current_company.authentication_type

        if current_company.integration_types.include?("bamboo_hr") && updated_user.bamboo_id.present?
          if (params[:manager_id] && user.manager_id != params[:manager_id]) ||
            (params[:title] && user.title != params[:title]) ||
            (params[:team_id] && user.team_id != params[:team_id]) ||
            (params[:location_id] && user.location_id != params[:location_id])
            ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "Job Information")
          end
          ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "preferred_name") if params[:preferred_name] && user.preferred_name != params[:preferred_name]
          ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "Employment Status") if params[:employee_type] && user.employee_type != params[:employee_type]
          ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "personal_email") if params[:personal_email] && user.personal_email != params[:personal_email]
          ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "last_name") if params[:last_name] && user.last_name != params[:last_name]
          ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "first_name") if params[:first_name] && user.first_name != params[:first_name]
          ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "email") if params[:email] && user.email != params[:email]
          ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "Profile Photo") if params[:is_profile_image_updated].present?
          ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(updated_user, "start_date") if params[:start_date] && params[:start_date].to_date.strftime("%Y-%m-%d") != user.start_date.to_s
        end

        if auth_type == "one_login" && updated_user.one_login_id.present?
          manage_one_login_updates(user, params)
        end

        if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| current_company.integration_types.include?(api_name) }.present?
        
          if params[:personal_email] && user.personal_email != params[:personal_email]
            update_adp_profile(user.id, 'Personal Email', nil, params[:personal_email]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
          end
          if params[:email] && user.email != params[:email]
            update_adp_profile(user.id, 'Email', nil, params[:email]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
          end
          if params[:preferred_name] && user.preferred_name != params[:preferred_name]
            update_adp_profile(user.id, 'Preferred Name', nil, params[:preferred_name]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
          end
          if params[:first_name] && user.first_name != params[:first_name]
            update_adp_profile(user.id, 'First Name', nil, params[:first_name]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
          end
          if params[:last_name] && user.last_name != params[:last_name]
            update_adp_profile(user.id, 'Last Name', nil, params[:last_name]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
          end
          if params[:title] && user.title != params[:title]
            update_adp_profile(user.id, 'Job Title', nil, params[:title]) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
          end
          if params[:manager_id] && user.manager_id != params[:manager_id]
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

      def download_all_documents
        user  = current_company.users.find_by_id(params[:id])
        url_key = SecureRandom.urlsafe_base64
        firebase = DownloadAllDocumentsJob.perform_now user, url_key, params[:user_document_connection_id]

        render json: {url_key: url_key, url: firebase.body}, status: 200
      end

      def view_all_documents
        user = current_company.users.find_by(id: params[:id])
        urls =[]
        if user.present? && params[:user_document_connection_id].present?
          urls = user.get_user_document_connections_urls(params[:user_document_connection_id])
        end
        render json: {urls: urls}, status: 200
      end

      def download_profile_image
        user = current_company.users.find_by_id(params[:id])
        render json: {url: user.profile_image.file.url}, status: 200
      end

      def get_organization_chart
        tree = User.get_organization_tree(current_company)
        render json: {org_root_present: current_company.organization_root.present?, tree: tree}.to_json, status: 200
      end

      def get_parent_ids
        user = current_company.users.find_by_id(params[:id])
        parent_ids = User.find_parents_ids(user)
        render json: { parent_ids: parent_ids }, status: 200
      end

      def profile_fields_history
        render json: Profile::AUDITING_FIELDS , status: 200
      end

      def update_notification
        return if current_user.id != params[:id].to_i
        current_user.update!(params_permit)
        render json: current_user, status: 200
      end

      def get_notification_settings
        respond_with current_user, serializer: UserSerializer::Notification
      end

      def manager_form_snapshot_creation
        user = current_company.users.find_by(id: params[:id])
        ::CustomTables::CustomTableSnapshotManagement.new.manage_manager_form_snapshots(current_user, user, current_company, params[:snapshots_data]) if user.present? && current_user.present?
        head :ok
      end

      def manage_performance_tab
        render json: { pm_integration_path: current_company.pm_integration_path(params[:name]) + @user.pm_integration_uid(params[:name]).gsub('employee_', '') }, status: 200
      end

      def canny_identify_details
        respond_with ActiveModelSerializers::SerializableResource.new(@user, each_serializer: UserSerializer::CannyIdentify)
      end

      def reassign_manager_activities_count
        pending_pto_requests_count = PtoRequest.pending_pto_request(ApprovalChain.approval_types[:manager], current_company, params[:user_id])&.count
        pending_paperwork_request_count = PaperworkRequest.template_without_all_signed(current_company, params[:user_id], params[:previous_manager_id], ['all_signed', 'failed'])&.count
        pending_tasks_count = User.manager_reassign_tasks(params[:user_id], params[:previous_manager_id], Task.task_types[:manager])&.count
        render json: {time_off_count: pending_pto_requests_count, documents_count: pending_paperwork_request_count, task_count: pending_tasks_count}, status: 200
      end

      def reassign_manager_activities
        Users::ReassignManagerActivitiesJob.perform_async(current_company.id, params[:user_id], params[:previous_manager_id]) if params[:user_id].present? && params[:previous_manager_id].present?
      end

      def get_heap_data
        respond_with current_user, serializer: UserSerializer::HeapProperties, permissions: normalize_permissions_data
      end

      def get_manager_level_list
        user = current_company.users.find_by_id(params[:id])
        render json: { employee_managed_level: user&.manager_level_count() || 0, requestor_managed_level: current_user.manager_level_count() || 0 }, status: 200
      end

      def update_ui_switcher
        user = current_company.users.find_by_id(params[:id])
        user.update(ui_switcher: params[:ui_switcher])
        render json: true, status: 200
      end

      private

      def mentioned_users_params
        params.permit(:users => [])
      end

      def people_paginated_params
        page = (params[:start].to_i / params[:length].to_i) + 1 rescue 1
        if params[:team]
          column_map = {"0": "preferred_full_name", "1": "current_stage", "2": "location_name", "3": "outstanding_owner_tasks_count"}
        elsif current_company.bulk_rehire_feature_flag.present?
          if current_user.role ==  'account_owner' || current_user.is_admin_with_view_and_edit_people_page?
            if params[:registered]
              column_map = {"1": "preferred_full_name", "2": "title", "3": "manager_name", "4": "location_name", "5": "team_name", "6": "email", "7": "employee_type"}
            else
              column_map = {"1": "preferred_full_name", "2": "termination_date", "3": "title", "4": "manager_name", "5": "location_name", "6": "team_name", "7": "employee_type"}
            end
          else
            if params[:registered]
              column_map = {"0": "preferred_full_name", "1": "title", "2": "manager_name", "3": "location_name", "4": "team_name", "5": "email", "6": "employee_type"}
            else
              column_map = {"0": "preferred_full_name", "1": "termination_date", "2": "title", "3": "manager_name", "4": "location_name", "5": "team_name", "6": "employee_type"}
            end
          end
          employee_status_field = current_company.custom_fields.find_by(field_type: CustomField.field_types[:employment_status])
          params.merge!(employee_status_field_id: employee_status_field.try(:id)) if employee_status_field.present?

        else
          if current_user.role ==  'account_owner' || current_user.is_admin_with_view_and_edit_people_page?
            column_map = {"1": "preferred_full_name", "2": "title", "3": "team_name", "4": "location_name", "5": "manager_name", "6": "email"}
          else
            column_map = {"0": "preferred_full_name", "1": "title", "2": "team_name", "3": "location_name", "4": "manager_name", "5": "email"}
          end
        end
        sort_column = column_map[params["order"]["0"]["column"].to_sym] rescue ""
        sort_order = params["order"]["0"]["dir"] rescue "asc"

        if sort_column.nil?
          sort_column = "preferred_full_name"
        end

        params.merge!(
          company_id: current_company.id,
          page: page,
          per_page: params[:length].to_i,
          order_column: sort_column,
          order_in: sort_order,
          term: (!params["search"] || params["search"]["value"].empty?) ? nil : params["search"]["value"]
        )

        if params[:integration_name] == "xero"
          filters = current_company.integration_instances.find_by_api_identifier("xero")&.filters
          location_id = (filters.blank? || filters["location_id"] == ["all"]) ? nil : filters["location_id"]
          team_id = (filters.blank? || filters["team_id"] == ["all"]) ? nil : filters["team_id"]
          employee_type = (filters.blank? || filters["employee_type"] == ["all"]) ? nil : filters["employee_type"]
          params.merge!(location_id: location_id, team_id: team_id, employee_type: employee_type)
        end

        params
      end

      def overdue_task_owner_count_params
        collection_params.merge(is_owner_view: true, state: "in_progress", transition: "latest", not_pending: true, count: true, pending: false, overdue: true)
      end

      def overdue_task_count_params
        collection_params.merge(permission: true, state: "in_progress", transition: "latest", not_pending: true, count: true, pending: false, overdue: true)
      end

      def task_owner_count_params
        collection_params.merge(is_owner_view: true, count: true, state: "in_progress", transition: "latest", not_pending: true)
      end

      def task_count_params
        collection_params.merge(permission: true, count: true, state: "in_progress", transition: "latest", not_pending: true)
      end

      def collection_params
        params.merge(company_id: current_company.id, manager_users: current_company.directory_managers)
      end

      def params_permit
        params.permit(:slack_notification,:email_notification)
      end

      def normalize_permissions_data
        default_tables, permissions = {}, {}
        current_company.custom_tables.default.each{ |table| default_tables[table.id] = table.name.parameterize(separator: '_')}
        current_user.user_role.permissions.each do |permission_type, permission_data|
          permission_data.each do |key, value|
            key = default_tables[key.to_i] if %w[own_role_visibility other_role_visibility].include? permission_type
            permissions["#{permission_type}_#{key}"] = value if key
          end
        end
        permissions
      end

      def is_valid_email_update?(tempUser)
        (['account_owner', 'admin'].include? (current_user.role)) || can_employee_update_email?(tempUser)
      end

      def can_employee_update_email?(tempUser)
        (current_user == tempUser && 
        current_user.role == 'employee' &&
        current_user.get_default_field('Company Email').first['collect_from'].eql?('new_hire'))
      end

    end
  end
end
