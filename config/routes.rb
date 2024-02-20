Rails.application.routes.draw do
  if ['production', 'staging', 'demo'].include?(Rails.env)
    require 'sidekiq-ent/web'
  else
    require 'sidekiq/web'
  end
   
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  
  require 'sidekiq-status/web'
  authenticate :admin_user, lambda { |u| u.active? && (u.super_user? || u.developer?) } do
    mount Sidekiq::Web, at: 'admin/sidekiq'
  end

  authenticate :admin_user, lambda { |u| u.active? && (u.super_user? || u.support?)  } do
    mount Blazer::Engine, at: "admin/blazer"
  end

  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self) rescue ActiveAdmin::DatabaseHitDuringLoad
  get '/linkedin-onboard', to: 'linkedin_login#onboard'
  post '/linkedin-onboard', to: 'linkedin_login#verify_domain'

  get '/admin/loggings', to: 'admin_users/loggings#index';
  get '/admin/integration', to: 'admin_users/loggings#integration';
  get '/admin/webhook_logs', to: 'admin_users/loggings#webhook';
  get '/admin/sapling_api', to: 'admin_users/loggings#sapling_api';
  get '/admin/ct_logs', to: 'admin_users/loggings#ct_logs';
  get '/admin/email_logs', to: 'admin_users/loggings#email_logs';
  get '/admin/pto_logs', to: 'admin_users/loggings#pto_logs';
  get '/admin/overall_logs', to: 'admin_users/loggings#overall_logs';
  get '/admin/papertrail_logs', to: 'admin_users/loggings#papertrail_logs'
  get '/admin/export_loggings', to: 'admin_users/loggings#export_loggings';
  
  get '/admin/general_log/:id', to: 'admin_users/loggings#general_logs_show'
  get '/admin/integration_log/:id', to: 'admin_users/loggings#integration_logs_show'
  get '/admin/api_log/:id', to: 'admin_users/loggings#api_logs_show'
  get '/admin/webhook_log/:id', to: 'admin_users/loggings#webhook_logs_show'
  get '/admin/papertrail_log/:id', to: 'admin_users/loggings#papertrail_logs_show'

  root 'welcome#index'
  get 'check_subdomain', to: 'welcome#check_subdomain'
  match '/orgchart:token' => 'welcome#get_orgchart', :as => 'get_orgchart', via: [:get]
  mount_devise_token_auth_for 'User', at: '/api/v1/auth', controllers: {
    sessions:  'api/v1/auth/sessions',
    passwords:  'api/v1/auth/passwords',
    token_validations: 'api/v1/auth/token_validations',
    registrations: 'api/v1/auth/registrations',
    omniauth_callbacks: 'api/v1/auth/omniauth_callbacks'
  }
  get '/api/health', to: 'welcome#health'
  get '/admin/health', to: 'welcome#health'

  match '/slack_respond' => 'api/v1/admin/slack_integrations#slack_respond', :as => 'slack_respond', via: [:post]
  match '/slack_uninstall' => 'api/v1/admin/slack_integrations#slack_uninstall', :as => 'slack_uninstall', via: [:post]
  match '/slack_auth' => 'api/v1/admin/slack_integrations#slack_auth', :as => 'slack_auth', via: [:get]
  match '/slack_help' => 'api/v1/admin/slack_integrations#slack_help', :as => 'slack_help', via: [:post]
  match '/get_slack_command_data' => 'api/v1/admin/slack_integrations#get_slack_command_data', :as => 'get_team_details', via: [:post]
  match '/api/v1/oauth2callback' => 'api/v1/admin/gsuite_accounts#oauth2callback', :as => 'oauth2callback', via: [:get]
  match '/api/v1/gsheet_oauth2callback' => 'api/v1/admin/gsheets#gsheet_oauth2callback', :as => 'gsheet_oauth2callback', via: [:get]
  match '/smart_recruiters_authorize' => 'api/v1/admin/webhook_integrations/smart_recruiters#smart_recruiters_authorize', :as => 'smart_recruiters_authorize', via: [:get]
  match '/smart_recruiters_authorize/callback' => 'api/v1/admin/webhook_integrations/smart_recruiters#callback', :as => 'smart_recruiters_authorize_callback', via: [:get]
  match '/api/integrations_authorize/callback' => 'api/v1/webhook/integrations_authorize_callback#callback', :as => 'integrations_authorize_callback', via: [:get]
  match '/api/v1/deputy_authorize' => 'api/v1/admin/onboarding_integrations/deputy#authorize', :as => 'authorize', via: [:get]
  match '/api/v1/active_directory_authorize' => 'api/v1/admin/onboarding_integrations/active_directory#active_directory_authorize', :as => 'active_directory_authorize', via: [:get]
  match '/api/v1/beta/profiles/fields/:id' => 'api/v1/beta/profiles#fields', :as => 'fields', via: [:get]
  match '/api/v1/jazz' => 'api/v1/webhook/jazz#create', :as => 'create', via: [:post]
  match '/api/v1/asana' => 'api/v1/webhook/asana#create', :as => 'asana_create', via: [:post]
  match '/api/v1/sendgrid_events' => 'api/v1/webhook/sendgrid#events', :as => 'sendgrid_events', via: [:post]
  match '/api/v1/ats/custom/authenticate' => 'api/v1/webhook/custom_ats#authenticate', :as => 'custom_ats_authenticate', via: [:get]
  match '/api/v1/ats/custom/create' => 'api/v1/webhook/custom_ats#create', :as => 'custom_ats_create', via: [:post]
  match '/gusto-callback' => 'api/v1/admin/onboarding_integrations/gusto#authorize', via: [:get]  
  match '/api/v1/beta/adminsignup' => 'api/v1/beta/signup#create', via: [:post]
  match '/api/v1/beta/userlogin' => 'api/v1/beta/signup#authorize', via: [:get]
  match '/api/v1/beta/passwordstrength' => 'api/v1/beta/signup#password_strength', via: [:get]
  match '/api/v1/beta/profiles/get_sapling_profile' => 'api/v1/beta/profiles#get_sapling_profile', via: [:get]
  match '/api/v1/beta/groupfields/group_fields' => 'api/v1/beta/groupfields#group_fields', :as => 'group_fields', via: [:get]

  get '/403.html' => 'errors#forbidden_error', via: [:get]

  devise_scope :user do
    get '/admin/admin_users/sessions/change_password_form'=>'admin_users/sessions#change_password_form',via: :get
    post '/admin/admin_users/sessions/update_password'=>'admin_users/sessions#update_password',via: :post
  end

  resources :errors, only: [] do
    collection do
      get :not_found
    end
  end
  namespace :api, except: [:new, :edit], defaults: { format: 'json' } do
    namespace :v1 do
      match '/auth/omniauth_callbacks/consume_saml_response' => 'auth/omniauth_callbacks#consume_saml_response', :as => 'consume_saml_response', via: [:post]
      match '/saml/init' => 'saml#init', :as => 'init', via: [:get]
      match '/admin/gsuite_accounts/get_gsuite_auth_credential' => 'admin/gsuite_accounts#get_gsuite_auth_credential', :as => 'get_gsuite_auth_credential', via: [:get]
      match '/admin/gsuite_accounts/remove_credentials' => 'admin/gsuite_accounts#remove_credentials', :as => 'remove_credentials', via: [:get]
      match '/admin/gsheets/get_authorization_status' => 'admin/gsheets#get_authorization_status', :as => 'get_authorization_status', via: [:get]
      match '/admin/gsheets/export_to_google_sheet' => 'admin/gsheets#export_to_google_sheet', :as => 'export_to_google_sheet', via: [:get]
      resources :custom_table_user_snapshots, only: [:create, :destroy, :update, :show] do
        collection do
          post :mass_create
          get :updates_page_ctus
          get :user_approval_snapshot_min_date
          get :paginated_dashboard_approval_requests
          get :email_dashboard_approved_requests
        end
        member do
          get :dashboard_approval_requests
          post :dispatch_request_change_email
        end
      end
      resources :uploaded_files, only: [:create, :update, :destroy] do
        collection do
          post :destroy_all_unused
          post :scan_file
        end
      end
      resources :calendar_events, only: [:index, :show] do
        collection do
          get :get_milestones
        end
      end
      resources :request_informations, only: [:show, :update] do
        collection do
          get :show_request_information_form
        end
      end
      resources :pto_requests do
        collection do
          get :historical_requests
          get :upcoming_requests
          get :get_users_out_of_office
          get :hours_used
        end
        member do
          put :cancel_request
          put :approve_or_deny
        end
      end
      resources :pto_adjustments, only: [:create, :index, :destroy]
      resources :assigned_pto_policies do
        collection do
          get :estimated_balance
        end
      end
      resources :invites, only: [] do
        get '/:token', on: :collection, action: :show, as: :accept_invitation
      end
      resources :companies, only: [] do
        collection do
          get :current
          get :auth_current
        end
      end
      resources :email_activities, only: [:index]
      resources :email_ptos, only: [] do
        member do
          get :approve
          get :deny
          post :post_comment
          get :get_request_by_hash
          get :get_request_user
        end
      end

      resources :manager_forms, only: [:show] do
        collection do
          get :show_manager_form
        end
      end
      resources :workspace_images, only: :index
      resources :company_links, only: :index
      resources :workspaces, only: [:show, :update, :destroy] do
        collection do
          get :basic
        end
      end
      resources :workspace_members, only: [:update, :create, :destroy] do
        collection do
          get :paginated
          get :get_members
        end
      end
      resources :recaptcha, only: [] do
        collection do
          get :verify
        end
      end
      resources :users, only: [:index, :update, :show] do
        resource :profile, only: [:update] do
          member do
            post :create_requested_fields_for_profile_cs_approval
          end
        end
        member do
          get :user_with_pto_policies
          get :basic_info
          post :canny_identify_details
          post :update_ui_switcher
        end
        collection do
          get :email_availibility
          get :paginated
          get :basic
          get :basic_search
          get :home_user
          get :user_with_pending_ptos
          get :people_paginated
          get :total_active_count
          get :dashboard_people_count
          get :get_my_activities_count
          get :get_team_activities_count
          get :activities_count
          get :home_group_paginated
          get :people_paginated_count
          get :get_organization_chart
          get :mentions_index
          get :mentioned_users
          get :profile_fields_history
          get :get_notification_settings
          get :user_algolia_mock
          get :get_secure_algoli_key
          get :verify_password_strength
          get :reassign_manager_activities_count
          get :reassign_manager_activities
          get :user_approval_values
          post :manager_form_snapshot_creation
        end
        member do
          get :download_all_documents
          get :view_all_documents
          get :get_parent_ids
          get :download_profile_image
          get :manage_performance_tab
          put :update_notification
          post :create_requested_fields_for_employee_approval
          get :get_heap_data
          get :get_manager_level_list
        end
        resources :task_user_connections, only: :none do
          collection do
            post :assign
            post :bulk_assign
          end
        end
      end
      resources :teams, only: [:index, :show] do
        member do
          get :basic
        end
        collection do
          get :basic_index
          get :report_index
          get :people_page_index
        end
      end
      resources :locations, only: [:index] do
        collection do
          get :states
          get :basic_index
          get :report_index
          get :people_page_index
        end
      end
      resources :address, only: [] do
        collection do
          get :countries_index
          get :states_index
          get :cities_index
        end
      end
      resources :groups, only: [:index]
      resources :tasks, only: [:index, :update] do
        collection do
          get :basic_index
        end
      end
      resources :custom_fields, only: [:index, :update] do
        collection do
          get :custom_groups
          get :home_group_field
          get :preboarding_visible_field_index
          get :preboarding_page_index
          get :home_info_page_index
          get :home_job_details_page_index
          get :mcq_custom_fields
          get :people_page_custom_groups
          get :report_custom_groups
          post :create_requested_fields_for_cs_approval
          post :bulk_update_custom_fields_to_integrations
        end
      end
      resources :workstreams, only: [:index] do
        collection do
          get :basic_index
          get :workspace_index
          get :get_custom_workstream
        end
      end
      resources :user_roles, only: [:index, :create, :update, :destroy, :show] do
        collection do
          get :full_index
          get :simple_index
          get :home_index
          get :remove_user_role
          get :add_user_role
          post :create_requested_fields_for_user_role_approval
          get :custom_alert_page_index
        end
      end
      resources :email_templates, only: [:index]
      resources :task_user_connections, only: [:index, :update, :show] do
        collection do
          get :paginated
          get :task_due_dates
          get :all_completed
          get :buddy_activities_count
          get :get_tasks_count
          get :get_active_task_users
          put :bulk_complete
          put :update_inactive_tasks
          get :show_task
          get :show_inactive_task
          get :workspace_paginated
          get :get_workspace_tasks_count
          put :workspace_task_update
          get :workspace_show
          post :update_task_user_connection_on_manager_change
          post :soft_delete_workflow
          post :soft_delete_task
          post :delete_offboarding_tasks
          post :hard_delete_workflow
          post :hard_delete_task
          post :undo_delete_workflow
          put :undo_delete_task
        end
      end
      resources :user_document_connections, only: [:index, :update, :destroy] do
      end

      resources :paperwork_requests, only: [:index, :show, :destroy] do
        member do
          get :signature
          post :submitted
          get :download_document_url
        end
        collection do
          post :signed_paperwork
        end
      end

      resources :calendar_feeds, only: [:create, :index, :update, :destroy] do
        collection do
          get :feed
        end
      end

      resources :comments, only: [:create, :index]
      resources :activities, only: [:create, :index] do
        collection do
          get :ctus_activities
          get :pending_ctus_activities
        end
      end
      resources :sub_task_user_connections, only: [:index, :update]
      resources :personal_documents do
        member do
          get :download_url
        end
      end
      resources :collective_documents, only: [] do
        collection do
          get :paginated_documents
        end
      end

      namespace :webhook do
        resources :jazz, only: [:create]
        resources :linked_in, only: [] do
          collection do
            post :callback
            get :onboard
          end
        end
        resources :custom_ats, only: [:create] do
          collection do
            get :authenticate
          end
        end
        resources :hire_bridge, only: [:create]        
      end

      namespace :beta do
        resources :profiles, only: [:index, :show, :update, :create] do
          collection do
            get :fields
          end
        end
        resources :address, only: [] do
          collection do
            get :countries
            get :states
          end
        end

        resources :pendinghires, only: [:index, :show, :update, :create]
        resources :tasks, only: [:index, :update, :destroy]
        resources :workflows, only: [:index, :show, :create] do
          collection do
            post :tasks
          end
        end
        resources :webhooks
      end

      resources :custom_tables, only: [] do
        collection do
          get :home_index
        end
      end

      resources :pto_policies, only: [] do
        collection do
          get :filter_policies
          get :policy_eoy_balance
        end
      end

      resource :surveys, only: [] do
        get :get_task_survey
      end

      resources :survey_answers, only: [:create]

      resources :custom_section_approvals, only: [:destroy, :update] do
        collection do
          get :get_custom_section_approval_values
          get :updates_page_cs_approvals
          get :paginated_dashboard_cs_approval_requests
          get :dashboard_cs_approval_requests
          get :email_dashboard_approved_requests
          post :create_profile_approval_with_requested_fields
          post :dispatch_request_change_email
          delete :destroy_requested_fields
        end
      end

      namespace :admin do
        resources :custom_tables, only: [:create, :index, :destroy, :update] do
          collection do
            get :home_index
            get :webhook_page_index
            get :reporting_index
            get :permission_page_index
            get :group_page_index
            get :bulk_onboarding_index
            get :custom_tables_bulk_operation
            post :mass_create
          end
          member do
            get :custom_table_columns
          end
        end

        resources :smart_assignment_configurations do
          collection do
            get :get_sa_configuration
          end
        end

        resources :process_types, only: [:index, :create]

        resources :request_informations, only: [:create] do
          collection do
            post :bulk_request
          end
        end

        resources :webhooks do
          collection do
            get :paginated
            post :receive_test_event
            post :new_test_event
            put :subscribe_zap
            delete :unsubscribe_zap
            get :authenticate_zap
            get :generate_zap_key
            get :perform_list_zap
          end
          member do
            put :test_event
          end
        end

        resources :webhook_events, only: [:index, :show] do
          member do
            put :redeliver
          end
        end

        resources :api_keys, only: [:create, :index, :destroy]  do
          collection do
            get :generate_api_key
          end
        end

        resources :pto_policies do
          member do
            put :enable_disable_policy
            post :upload_balance
            post :duplicate_pto_policy
          end
          collection do
            get :enabled_policies
            get :pto_policy_paginated
            get :timeoff_pto_policy
          end
        end
        resources :custom_email_alerts do
          collection do
            get :paginated
            put :send_test_alert
            post :duplicate_alert
          end
        end
        resources :pending_hires, only: [:show, :destroy, :index, :update, :create] do
          collection do
            get :pending_hires_count
            get :paginated_hires
            put :update
            post :bulk_delete
            post :download_csv
            post :bulk_update
            post :create_bulk_users
          end
        end

        resources :integration_inventories, only: [:index, :show]
        resources :integration_instances, only: [:index, :create, :show, :update, :destroy] do
          collection do
            get :sync_now
            delete :destroy_instance_by_inventory
            get :authorize
            get :create_account
            get :get_credentials
          end
        end

        resources :workspaces, only: [:create, :index]
        resources :reports, only: [:create, :index, :show, :update, :destroy] do
          collection do
            get :report_csv
            get :get_reports
          end
          member do
            post :last_viewed
            post :duplicate
            post :export_report_to_sftp
            get :show_with_user_roles
            put :update_with_user_roles
          end
        end
        resources :field_histories, only: [:index, :update, :destroy] do
          member do
            get :show_identification_numbers
          end
        end
        resources :integrations, except: [:show, :new, :edit] do
          collection do
            get :check_slack_integration
            get :hire_unauth
            get :fetch_lever_requisition_fields
            post :sync_adp_us_users
            post :sync_adp_can_users
            get :fetch_adp_onboarding_templates
            get :generate_jazz_credentials
            post :enable_linked_in_integration
            get :generate_ats_credentials
          end
        end
        resources :calendar_feeds, only: [:update, :index, :create, :destroy]
        resources :document_upload_requests, except: [:new, :edit] do
          member do
            post :duplicate
          end
          collection do
            get :simple_index
            get :paginated_index
            get :paginated
            get :documents_count
            post :bulk_assign_upload_requests
          end
        end
        resources :histories, only: [:index] do
          member do
            post :delete_scheduled_email
            post :update_scheduled_email
          end
        end
        resources :user_document_connections, only: [:index, :create, :destroy] do
          member do
            put :update_state_draft_to_request
          end
          collection do
            post :bulk_document_assignment
            post :remove_draft_connections
          end
        end
        resources :email_templates, only: [:index, :create, :update, :destroy, :show] do
          collection do
            put :send_test_email
            get :paginated
            post :duplicate_template
            get :filter_templates
            get :get_bulk_onboarding_emails
          end
        end

        resources :general_data_protection_regulations, only: [:index, :create, :update]

        resources :jira_integrations, only: [:destroy] do
          collection do
            get :generate_keys
            get :initialize_integration
            get :authorize
            post :issue_updated
          end
        end

        resources :holidays, only: [:create, :update, :destroy, :show] do
          collection do
            get :holidays_index
            get :user_holidays
          end
        end

        resources :custom_field_options, only: [:create, :update, :destroy]

        resources :profile_templates, only: [:create, :show, :index, :update, :destroy] do
          member do
            post :duplicate
          end
        end
        resources :recommendation_feedbacks, only: [:create]
        resources :surveys, only: [:create, :show, :index, :update]

        resources :feedbacks, only: [:create, :index]

        resources :users, only: [:create, :show, :index, :update, :destroy], shallow: true do
          collection do
            get :paginated
            get :datatable_paginated
            get :basic
            get :autocomplete_user_request
            get :group_basic
            get :get_users_for_permissions
            get :offboarding_basic
            post :invite_user
            post :invite_users
            get :home_group_paginated
            get :all_open_activities
            get :all_open_tasks
            get :get_open_documents_count
            get :get_role_users
            get :activity_owners
            get :get_job_titles
            get :fetch_role_users
            post :bulk_delete
            get :get_managed_users
            post :create_ghost_user
            post :bulk_update_managers
            post :reassign_manager_offboard_custom_snapshots
            post :back_to_admin
            post :bulk_reassing_manager
            post :create_offboard_custom_snapshots
            post :create_manager_change_custom_snapshots
            post :bulk_onboard_users
            post :check_email_uniqueness
            post :send_due_documents_email
            post :import_users_data
            post :bulk_update
            post :bulk_assign_onboarding_template
            post :pending_hire_draft_documents
            get :user_termination_types
          end

          member do
            post :send_tasks_email
            post :test_digest_email
            post :offboard_user
            post :complete_user_activities
            post :update_start_date
            post :update_termination_date
            post :update_task_date
            post :resend_invitation
            post :cancel_offboarding
            post :set_manager
            post :create_onboard_custom_snapshots
            post :restore_user_snapshots
            post :create_rehired_user_snapshots
            post :login_as_user
            post :assign_individual_policy
            post :unassign_policy
            post :update_pending_hire_user
            post :send_onboarding_emails
            post :update_user_emails
            post :scheduled_email_count
            post :change_onboarding_profile_template
          end

          resources :user_emails, only: [:create, :update, :destroy, :show] do
            member do
              put :restore
            end
            collection do
              post :schedue_email
              get :emails_paginated
              post :create_incomplete_email
              post :delete_incomplete_email
              post :create_default_onboarding_emails
              post :create_default_offboarding_emails
              post :contact_us
              get :get_metrics
            end
          end

          resources :task_user_connections, only: :none do
            collection do
              post :assign
              post :bulk_assign
              post :destroy_by_filter
            end
          end

          resources :invites do
            collection do
              post :resend_invitation_email
            end
          end

          resources :workstreams, only: :none do
            collection do
              get :connected
            end
            member do
              get :fetch_stream_tasks
              post :duplicate_workstream
              post :duplicate_workstream_task
            end
          end
        end

        resources :companies, only: [:index] do
          collection do
            get :current
            get :revoke_token
            get :show_webhook_token
            get :company_with_team_and_locations
            get :with_managers
            get :default_profile_setup
            put :update_shareableurl
            get :profile_setup_page
            put :update
            get :visualization_data
            get :turnover_data
          end
        end

        resources :locations, except: [:new, :edit] do
          collection do
            get :basic_index
            get :get_locations
            get :states
            get :search
            get :paginated_locations
            get :get_location_field
          end
        end

        resources :groups, except: [:new, :edit]

        resources :teams, except: [:new, :edit] do
          collection do
            get :basic_index
            get :get_teams
            get :search
            get :paginated_teams
            get :get_team_field
          end
        end

        resources :documents, except: [:new, :edit] do
          collection do
            get :paginated
          end
        end

        resources :paperwork_packets, except: [:new, :edit] do
          member do
            post :duplicate_packet
          end
          collection do
            get :basic_index
            get :smart_packet_basic_index
            get :paginated_index
            post :bulk_assign
            post :get_document_token
            post :send_bulk_packet_email
          end
        end

        resources :paperwork_templates, except: [:new, :edit] do
          member do
            post :duplicate
            post :finalize
            get  :migrate_template
          end
          collection do
            get :basic_index
            get :smart_basic_index
            post :get_edit_url
            get :paginated_collective_documents
            get :paginated_collective_dashboard_documents
          end
        end
        resources :paperwork_requests, only: [:create, :destroy, :index] do
          collection do
            post :assign
            post :remove_draft_requests
            post :bulk_paperwork_request_assignment
          end
        end
        resources :sftps,only: [:create, :destroy, :show, :update, :index] do
          collection do
            get :paginated
          end
          member do
            post :duplicate
            post :test
          end
        end

        namespace :active_admin do
          resource :admin_requests, only: [] do
            member do
              get :document_url
              delete :delete_paperwork_request
              get :load_company_team_and_locations
            end
          end
        end

        resources :custom_fields, only: [:index, :create, :update, :destroy] do
          collection do
            get :get_adp_wfn_fields
            get :reporting_page_index
            get :employment_status_fields
            get :custom_groups
            get :custom_groups_org_chart
            get :export_employee_record
            get :onboarding_page_index
            get :onboarding_info_fields
            get :offboarding_page_index
            get :request_info_index
            get :paginated_custom_groups
            get :sa_configuration_custom_groups
            get :sa_configuration_onboarding_custom_groups
            post :create_requested_fields_for_cs_approval
          end
          member do
            post :update_custom_group
            post :delete_sub_custom_fields
            post :update_user_custom_group
            post :duplicate
          end
        end
        
        resources :custom_sections, only: [:index, :update] do
          collection do
            get :webhook_page_index
            get :get_custom_sections
          end
        end

        resources :tasks, only: :none do
          collection do
            get :paginated
            get :workflow_task_paginated
          end
          member do
            post :duplicate_task
          end
        end


        resources :task_user_connections, only: :none do
          collection do
            post :bulk_update_task_user_conenctions
            post :unassign
          end
        end

        resources :workstreams, except: [:new, :edit], shallow: true do
          member do
            post :update_task_owners
            post :update_individual_task_owner
            get :get_workstream_with_sorted_tasks
          end
          resources :tasks, except: [:new, :edit] do
            member do
              post :update_workstream
            end
          end
          collection do
            get :basic
            get :get_custom_workstream
            get :get_active_tasks
            get :get_workstreams_with_tasks
            get :get_template_tasks
            get :paginated_workstreams
            post :bulk_update_template_task_owners
          end
        end

        namespace :email_preview do
          resources :user_mailer, only: :none do
            member do
              get :invite
            end
          end
        end


        namespace :onboarding_integrations do
          resources :bamboo, only: [:create] do
            collection do
              get :job_title_index
              post :create_job_title
            end
          end

          resources :xero, only: [:new] do
            collection do
              get :authorize
              get :get_organisations
              get :get_payroll_calendars
              get :get_employee_group_names
              get :get_pay_templates
            end
          end

          resources :active_directory, only: [:new] do
            collection do
              get :active_directory_authorize
            end
          end

          resources :deputy, only: [:new] do
            collection do
              get :authorize
            end
          end

          namespace :gusto do
            get :authorize
          end
        end

        namespace :webhook_integrations do
          resources :greenhouse, only: [:create] do
            collection do
              post :mail_parser
            end
          end
          resources :lever, only: [:create]
          resources :namely, only: [:create] do
            collection do
              get :job_title_index
              get :departments_and_locations_index
              get :job_tier_index
              post :create_job_tier_and_title
            end
          end
          resources :adp_subscriptions, only: [] do
            collection do
              get :create_subscription
              get :change_subscription
              get :cancel_subscription
              get :notify_subscription
              get :add_on
              get :verify
            end
          end
          resources :adp_subscription_users, only: [] do
            collection do
              get :assign_users
              get :unassign_users
            end
          end
          resources :workable, only: [:create] do
            collection do
              post :workable_authorize
              get :subscribe
              get :unsubscribe
            end
          end
          resources :smart_recruiters, only: [] do
            collection do
              get :smart_recruiters_authorize
              get :authenticate
              get :import
              get :server_response
            end
          end
          resources :fountain, only: [:create]
          resources :adp_workforce_now, only: [] do
            collection do
              get :job_titles_index
            end
          end
          # resources :workday, only: [] do
          #   collection do
          #     post :manage_sapling_users
          #   end
          # end
        end
      end
    end
  end
end
