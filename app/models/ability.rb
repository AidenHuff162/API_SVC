class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    company = user.company

    can [:signed_paperwork, :destroy], PaperworkRequest
    can :read, WorkspaceImage
    can :update, SubTaskUserConnection
    can :read, CompanyLink
    can [:read,:update,:delete], Comment

    if company.present?
      if user.admin? || user.account_owner?
        can :manage, User, company_id: company.id
        can :manage, Company, id: company.id
        can :manage, Location, company_id: company.id
        can :manage, Team, company_id: company.id
        can :manage, Document, company_id: company.id
        can :manage, PaperworkRequest, user: {company_id: company.id}
        can :manage, PaperworkTemplate, company_id: company.id
        can :manage, Workstream, company_id: company.id
        can :manage, ProcessType, company_id: company.id
        can :manage, Invite, user: { company_id: company.id }
        can :manage, UserEmail, user: { company_id: company.id }
        can [:schedue_email, :delete_incomplete_email], UserEmail, user: { company_id: company.id }
        can :manage, Task, workstream: { company_id: company.id }
        can :manage, UploadedFile, company_id: company.id
        can :manage, Profile, user: { company_id: company.id}
        can :manage, CustomField, company_id: company.id
        can :manage, PaperworkPacket, company_id: company.id
        can :manage, TaskUserConnection, task: {workstream: { company_id: company.id }}
        can :manage, DocumentUploadRequest, company_id: company.id
        can :manage, UserDocumentConnection, document_connection_relation: {document_upload_request: { company_id: company.id }}
        can :manage, EmailTemplate, company_id: company.id
        can :manage, History, company_id: company.id
        can :manage, Integration, company_id: company.id if user.account_owner? || can_manage_integrations(user)
        can :manage, Webhook, company_id: company.id if user.account_owner? || can_manage_integrations(user)
        can :manage, WebhookEvent, company_id: company.id if user.account_owner? || can_manage_integrations(user)
        can :manage, IntegrationInstance, company_id: company.id if user.account_owner? || can_manage_integrations(user)
        can :manage, IntegrationInventory if user.account_owner? || can_manage_integrations(user)
        can :manage, UserRole, company_id: company.id
        can :manage, CalendarFeed, company_id: company.id
        can :manage, Report, company_id: company.id
        can :manage, CustomFieldOption, custom_field: {company_id: company.id}
        can :manage, FieldHistory, field_changer: {company_id: company.id}
        can :manage, FieldHistory, custom_field: {company_id: company.id}
        can :manage, FieldHistory, integration: {company_id: company.id}
        can :manage, PtoRequest, user: {company_id: company.id}
        can :manage, PtoAdjustment, creator: {company_id: company.id}
        can :manage, Holiday, company_id: company.id
        can :manage, Workspace, company_id: company.id
        can :manage, WorkspaceMember, member: {company_id: company.id}
        can :manage, PtoPolicy, company_id: company.id
        can :manage, PersonalDocument, user: {company_id: company.id}
        can :manage, GeneralDataProtectionRegulation, company_id: company.id
        can :manage, CustomTable, company_id: company.id
        can :manage, CustomSection, company_id: company.id
        can :manage, CustomTableUserSnapshot, custom_table: {company_id: company.id} if user.account_owner?
        can [:create, :update, :destroy, :user_approval_snapshot_min_date, :mass_create], CustomTableUserSnapshot, custom_table: {company_id: company.id} if user.admin?
        can :manage, CustomSectionApproval, custom_section: {company_id: company.id} if user.account_owner?
        can [:destroy, :update, :get_custom_section_approval_values, :destroy_requested_fields], CustomSectionApproval, custom_section: {company_id: company.id} if user.admin?
        can :manage, CalendarEvent, company_id: company.id
        can :manage, CustomEmailAlert, company_id: company.id
        can :manage, ProfileTemplate, company_id: company.id
        can :manage, Survey, company_id: company.id
        cannot [:create_ghost_user], User if company.onboarding?
        can [:fetch_adp_onboarding_templates], Integration if can_access_dashboard(user)
        can :manage, SmartAssignmentConfiguration, company_id: company.id
        can :manage, Sftp, company_id: company.id if can_manage_integrations(user)

        if user.admin?
          can [:read, :destroy], ApiKey, company_id: company.id
        elsif user.account_owner?
          can :manage, ApiKey, company_id: company.id
          can :test_digest_email, User, company_id: company.id
        end
        can [:create, :bulk_request], RequestInformation, company_id: company.id
        can [:create], RecommendationFeedback, recommendation_owner_id: user.id
      else

        if user.email.present? && user.email.include?('@trysapling.com')
          can [:canny_identify_details], User, company_id: company.id
        end
        can :manage, user
        can [:paginated, :home_group_paginated, :user_with_pto_policies, :user_with_pending_ptos, :create_custom_snapshots, :manager_form_snapshot_creation, :back_to_admin, :view_all_documents, :manage_performance_tab, :get_heap_data], User, company_id: company.id
        can [:user_algolia_mock, :get_secure_algoli_key], User, company_id: company.id, manager_id: user.id
        can [:create], Document, company_id: company.id
        can :manage, Profile, user_id: user.id
        can :manage, UploadedFile do |file|
          if file.entity.present? && file.entity_type != 'PtoRequest'
            file.entity_id == user.id && file.entity_type == 'User'
          elsif file.entity.present? && file.entity_type == 'PtoRequest'
            user.pto_requests.pluck(:id).include?(file.entity_id) && user.company_id == file.company_id
          else
            user.company_id == file.company_id
          end
        end
        can :manage, Task, workstream: { company_id: company.id }
        can [:show], PaperworkTemplate, company_id: company.id
        can :manage, PaperworkPacket, company_id: company.id
        can [:simple_index, :create, :bulk_assign_upload_requests], DocumentUploadRequest, company_id: company.id
        can :manage, UserDocumentConnection, document_connection_relation: {document_upload_request: { company_id: company.id }}
        can [:read, :update, :signature, :submitted, :create, :destroy, :download_document_url, :show], PaperworkRequest, user_id: user.id
        can [:read, :update, :signature, :submitted, :create, :destroy, :show], PaperworkRequest, co_signer_id: user.id
        can [:read, :default_profile_setup, :profile_setup_page], company
        can [:assign], PaperworkRequest, user: {company_id: company.id}
        can [:read, :basic_index, :basic, :report_index, :people_page_index], Team, company_id: company.id
        can [:read, :people_paginated, :basic, :home_user, :updates_page_ctus, :people_paginated_count, :total_active_count, :dashboard_people_count, :activities_count, :get_my_activities_count, :get_team_activities_count, :get_organization_chart, :get_parent_ids, :basic_search, :mentions_index, :verify_password_strength], User, company_id: company.id
        can [:read, :basic_index, :report_index, :people_page_index], Location, company_id: company.id
        can [:read, :update, :home_group_field, :custom_groups, :preboarding_visible_field_index, :export_employee_record, :preboarding_page_index, :home_info_page_index, :people_page_custom_groups, :mcq_custom_fields, :create_requested_fields_for_cs_approval, :bulk_update_custom_fields_to_integrations], CustomField, company_id: company.id
        can [:read, :update, :paginated, :task_due_dates, :get_tasks_count, :assign, :update_inactive_tasks, :show_inactive_task, :workspace_paginated, :get_workspace_tasks_count, :workspace_task_update, :workspace_show, :soft_delete_workflow, :hard_delete_workflow, :soft_delete_task, :hard_delete_task, :undo_delete_task, :undo_delete_workflow, :show_task, :update_task_user_connection_on_manager_change], TaskUserConnection, task: {workstream: { company_id: company.id }}
        can [:read, :basic_index, :get_custom_workstream], Workstream, company_id: company.id
        can [:update, :reassign_manager_activities_count, :reassign_manager_activities, :create_requested_fields_for_employee_approval], User, company_id: company.id, manager_id: user.id
        can [:update, :create_requested_fields_for_profile_cs_approval], Profile, user: {manager_id: user.id}
        can :read, FieldHistory, field_changer: {company_id: company.id}
        can :read, FieldHistory, custom_field: {company_id: company.id}
        can :read, FieldHistory, integration: {company_id: company.id}
        can [:read, :update, :create, :destroy], CalendarFeed, user: {id: user.id, company_id: company.id}
        can [:read, :update, :create, :destroy], CalendarFeed, user: {manager_id: user.id, company_id: company.id}
        can :manage, PtoRequest, user: {id: user.id, company_id: company.id}
        can :manage, PtoRequest, user: {manager_id: user.id, company_id: company.id}
        can :read, PtoRequest, user: {id: user.indirect_reports_ids, company_id: company.id}
        can :read, PtoAdjustment, assigned_pto_policy: {user: {id: user.id, company_id: company.id}}
        can :manage, PtoAdjustment, assigned_pto_policy: {user: {manager_id: user.id, company_id: company.id}}
        can [:read, :basic, :update, :destroy], Workspace, company_id: company.id
        can :manage, WorkspaceMember, workspace: {company_id: company.id}
        can [:read, :user_holidays], Holiday, company_id: company.id
        can :manage, PersonalDocument, user: {id: user.id, company_id: company.id}
        can :manage, PersonalDocument, user: {manager_id: user.id, company_id: company.id}
        can :manage, PersonalDocument, user: {id: user.indirect_reports_ids, company_id: company.id}
        can [:create, :update, :destroy, :show], CustomTableUserSnapshot, user: {id: user.id, company_id: company.id}
        can [:create, :update, :destroy, :show], CustomTableUserSnapshot, user: {manager_id: user.id, company_id: company.id}
        can [:create, :update, :destroy, :show], CustomTableUserSnapshot do |snapshot|
          if user.user_role.role_type == 'employee'
            snapshot&.user&.buddy_id == user.id || snapshot&.user&.custom_field_values&.where(coworker_id: user.id)&.take&.coworker_id == user.id
          else
            user.user_role.reporting_level == "direct_and_indirect" && user.cached_indirect_reports_ids.include?(snapshot.user.id)
          end
        end
        can [:home_index], CustomTable, company_id: company.id
        can [:get_custom_sections], CustomSection, company_id: company.id
        can [:read, :get_milestones], CalendarEvent, company_id: company.id
        can :download_document_url, PaperworkRequest, user: { manager_id: user.id }
        can [:read], ProfileTemplate, company_id: company.id
        can [:read], Survey, company_id: company.id
        if user.user_role.role_type == "manager" && (user.user_role.permissions["other_role_visibility"]["can_offboard_reports"] rescue false)
          can [:offboarding_basic, :get_managed_users, :offboard_user, :create_offboard_custom_snapshots, :reassign_manager_offboard_custom_snapshots], User, company_id: company.id
          can :offboarding_page_index, CustomField, company_id: company.id
          can :remove_draft_requests, PaperworkRequest, user: {company_id: company.id}
          can :index, EmailTemplate, company_id: company.id
          can [:basic, :get_active_tasks, :get_template_tasks, :get_workstream_with_sorted_tasks, :bulk_update_template_task_owners], Workstream, company_id: company.id
          can [:show, :create_default_offboarding_emails, :destroy, :update, :create, :create_incomplete_email], UserEmail, user: { company_id: company.id }
          can [:create], RecommendationFeedback, recommendation_owner_id: user.id
          can [:create], DocumentUploadRequest, company_id: company.id
        elsif user.user_role.role_type == "manager"
          can [:update, :create_requested_fields_for_cs_approval], CustomField, company_id: company.id
        end
      end
      can [:read, :update], RequestInformation, { requested_to_id: user.id, company_id: company.id, state: RequestInformation.states[:pending] }
      can [:read, :create], SurveyAnswer, task_user_connection: { owner_id: user.id }
      cannot [:update_ui_switcher], User do |u| 
        u.id != user.id
      end
    end
  end

  def can_manage_integrations user
    user.present? && user.user_role.present? && user.user_role.permissions['admin_visibility'].present? && user.user_role.permissions['admin_visibility']['integrations'].present? && user.user_role.permissions['admin_visibility']['integrations']  == 'view_and_edit'
  end

  def can_access_dashboard user
    user.present? && user.user_role.present? && user.user_role.permissions['admin_visibility'].present? && user.user_role.permissions['admin_visibility']['dashboard'].present? && user.user_role.permissions['admin_visibility']['dashboard']  == 'view_and_edit'
  end
end
