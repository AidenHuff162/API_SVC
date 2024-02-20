class InitSchema < ActiveRecord::Migration[5.1]
  def up
    # These are extensions that must be enabled in order to support this database
    enable_extension "plpgsql"
    create_table "active_admin_comments", id: :serial do |t|
      t.string "namespace"
      t.text "body"
      t.string "resource_id", null: false
      t.string "resource_type", null: false
      t.string "author_type"
      t.integer "author_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id"
      t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
      t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id"
    end
    create_table "active_admin_loggings", id: :serial do |t|
      t.integer "admin_user_id"
      t.text "action"
      t.integer "user_id"
      t.integer "company_id"
      t.integer "company_email_id"
      t.integer "version_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
    create_table "active_admin_managed_resources" do |t|
      t.string "class_name", null: false
      t.string "action", null: false
      t.string "name"
      t.index ["class_name", "action", "name"], name: "active_admin_managed_resources_index", unique: true
    end
    create_table "active_admin_permissions" do |t|
      t.integer "managed_resource_id", null: false
      t.integer "role", limit: 2, default: 0, null: false
      t.integer "state", limit: 2, default: 0, null: false
      t.index ["managed_resource_id", "role"], name: "active_admin_permissions_index", unique: true
    end
    create_table "activities", id: :serial do |t|
      t.text "description"
      t.string "activity_type"
      t.integer "activity_id"
      t.integer "agent_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "deleted_at"
      t.index ["activity_type", "activity_id"], name: "index_activities_on_activity_type_and_activity_id"
      t.index ["agent_id"], name: "index_activities_on_agent_id"
      t.index ["deleted_at"], name: "index_activities_on_deleted_at"
    end
    create_table "admin_users", id: :serial do |t|
      t.string "email", default: "", null: false
      t.string "encrypted_password", default: "", null: false
      t.string "reset_password_token"
      t.datetime "reset_password_sent_at"
      t.datetime "remember_created_at"
      t.integer "sign_in_count", default: 0, null: false
      t.datetime "current_sign_in_at"
      t.datetime "last_sign_in_at"
      t.inet "current_sign_in_ip"
      t.inet "last_sign_in_ip"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "encrypted_otp_secret"
      t.string "encrypted_otp_secret_iv"
      t.string "encrypted_otp_secret_salt"
      t.integer "consumed_timestep"
      t.boolean "otp_required_for_login"
      t.date "expiry_date"
      t.string "state"
      t.boolean "first_login", default: true
      t.string "access_token"
      t.string "email_verification_token"
      t.integer "role", limit: 2, default: 0, null: false
      t.index ["email"], name: "index_admin_users_on_email", unique: true
      t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
    end
    create_table "adp_subscription_users", id: :serial do |t|
      t.integer "adp_subscription_id"
      t.integer "zip_code"
      t.integer "bill_rate"
      t.string "password"
      t.boolean "app_admin"
      t.string "timezone"
      t.string "access_rights"
      t.string "username"
      t.string "title"
      t.string "department"
      t.string "identification_number"
      t.string "email"
      t.string "first_name"
      t.string "last_name"
      t.string "uuids"
      t.json "response_data"
      t.index ["adp_subscription_id"], name: "index_adp_subscription_users_on_adp_subscription_id"
    end
    create_table "adp_subscriptions", id: :serial do |t|
      t.string "event_type"
      t.string "subscriber_first_name"
      t.string "subscriber_last_name"
      t.string "subscriber_email"
      t.string "subscriber_uuid"
      t.string "company_name"
      t.string "company_uuid"
      t.string "organization_oid"
      t.string "no_of_users"
      t.string "associate_oid"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.json "response_data"
      t.string "env"
    end
    create_table "anonymized_data", id: :serial do |t|
      t.integer "user_id"
      t.json "user_data"
      t.json "address_data"
      t.json "phone_data"
      t.json "ssn_data"
      t.json "emergency_data"
      t.datetime "deleted_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.json "sin_data"
      t.index ["deleted_at"], name: "index_anonymized_data_on_deleted_at"
      t.index ["user_id"], name: "index_anonymized_data_on_user_id"
    end
    create_table "api_keys", id: :serial do |t|
      t.integer "company_id"
      t.integer "edited_by_id"
      t.string "name", null: false
      t.string "encrypted_key", null: false
      t.string "encrypted_key_iv", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["company_id"], name: "index_api_keys_on_company_id"
      t.index ["edited_by_id"], name: "index_api_keys_on_edited_by_id"
    end
    create_table "api_loggings", id: :serial do |t|
      t.integer "company_id"
      t.string "api_key"
      t.string "end_point"
      t.json "data"
      t.string "status"
      t.string "message"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["company_id"], name: "index_api_loggings_on_company_id"
    end
    create_table "approval_chains", id: :serial do |t|
      t.string "approvable_type"
      t.integer "approvable_id"
      t.integer "approval_type"
      t.string "approval_ids", array: true
      t.index ["approvable_type", "approvable_id"], name: "index_approval_chains_on_approvable_type_and_approvable_id"
    end
    create_table "approval_requests", id: :serial do |t|
      t.integer "approval_chain_id"
      t.string "approvable_entity_type"
      t.integer "approvable_entity_id"
      t.integer "request_state"
      t.index ["approvable_entity_type", "approvable_entity_id"], name: "approval_requests_and_approvable_entity"
      t.index ["approval_chain_id"], name: "index_approval_requests_on_approval_chain_id"
    end
    create_table "assigned_pto_policies", id: :serial do |t|
      t.integer "pto_policy_id"
      t.integer "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.float "balance", default: 0.0
      t.boolean "is_balance_calculated_before", default: false
      t.date "balance_updated_at"
      t.date "start_of_accrual_period"
      t.datetime "deleted_at"
      t.date "first_accrual_happening_date"
      t.float "carryover_balance", default: 0.0
      t.boolean "manually_assigned", default: false
      t.index ["pto_policy_id", "user_id", "deleted_at"], name: "unique_assigned_pto_policy", unique: true
      t.index ["pto_policy_id"], name: "index_assigned_pto_policies_on_pto_policy_id"
      t.index ["user_id"], name: "index_assigned_pto_policies_on_user_id"
    end
    create_table "blazer_audits", id: :serial do |t|
      t.integer "user_id"
      t.integer "query_id"
      t.text "statement"
      t.string "data_source"
      t.datetime "created_at"
    end
    create_table "blazer_checks", id: :serial do |t|
      t.integer "creator_id"
      t.integer "query_id"
      t.string "state"
      t.string "schedule"
      t.text "emails"
      t.string "check_type"
      t.text "message"
      t.datetime "last_run_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
    create_table "blazer_dashboard_queries", id: :serial do |t|
      t.integer "dashboard_id"
      t.integer "query_id"
      t.integer "position"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
    create_table "blazer_dashboards", id: :serial do |t|
      t.integer "creator_id"
      t.text "name"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
    create_table "blazer_queries", id: :serial do |t|
      t.integer "creator_id"
      t.string "name"
      t.text "description"
      t.text "statement"
      t.string "data_source"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
    create_table "calendar_events", id: :serial do |t|
      t.integer "event_type"
      t.date "event_start_date"
      t.date "event_end_date"
      t.integer "eventable_id"
      t.string "eventable_type"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "company_id"
      t.integer "color"
      t.datetime "deleted_at"
      t.index ["company_id"], name: "index_calendar_events_on_company_id"
      t.index ["deleted_at"], name: "index_calendar_events_on_deleted_at"
    end
    create_table "calendar_feeds", id: :serial do |t|
      t.integer "feed_type", null: false
      t.string "feed_url", null: false
      t.string "feed_id"
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "user_id"
      t.index ["company_id"], name: "index_calendar_feeds_on_company_id"
      t.index ["feed_id", "feed_type"], name: "index_calendar_feeds_on_feed_id_and_feed_type"
      t.index ["user_id"], name: "index_calendar_feeds_on_user_id"
    end
    create_table "comments", id: :serial do |t|
      t.text "description"
      t.string "commentable_type"
      t.integer "commentable_id"
      t.integer "commenter_id"
      t.string "mentioned_users", default: [], array: true
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "company_id"
      t.datetime "deleted_at"
      t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
      t.index ["commenter_id"], name: "index_comments_on_commenter_id"
      t.index ["company_id"], name: "index_comments_on_company_id"
      t.index ["deleted_at"], name: "index_comments_on_deleted_at"
    end
    create_table "companies", id: :serial do |t|
      t.string "name", null: false
      t.string "subdomain", null: false
      t.datetime "deleted_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "abbreviation"
      t.string "email"
      t.string "brand_color"
      t.text "bio"
      t.string "time_zone", default: "Pacific Time (US & Canada)", null: false
      t.boolean "hide_gallery", default: false
      t.text "company_video"
      t.integer "owner_id"
      t.integer "users_count", default: 0
      t.integer "locations_count", default: 0
      t.integer "teams_count", default: 0
      t.json "prefrences", default: {}
      t.boolean "is_recruitment_system_integrated", default: false
      t.boolean "new_tasks_emails", default: false
      t.boolean "outstanding_tasks_emails", default: false
      t.boolean "new_coworker_emails", default: false
      t.integer "groups_count", default: 0
      t.integer "people_count", default: 0
      t.string "buddy", default: "Buddy"
      t.string "department", default: "Department"
      t.string "company_value", default: "Company Values"
      t.boolean "preboarding_complete_emails", default: false
      t.boolean "manager_emails", default: false
      t.integer "overdue_notification", default: 0
      t.string "phone_format", default: "Standard Phone Number"
      t.boolean "manager_form_emails", default: false
      t.boolean "include_activities_in_email", default: false
      t.text "welcome_note"
      t.integer "operation_contact_id"
      t.boolean "include_documents_preboarding", default: false
      t.string "department_mapping_key", default: "department"
      t.string "location_mapping_key", default: "location"
      t.boolean "enable_gsuite_integration", default: true
      t.string "group_for_home", default: "Department"
      t.boolean "new_pending_hire_emails", default: false
      t.string "company_about", default: "About Us"
      t.string "sender_name", default: "Sapling"
      t.string "paylocity_sui_state"
      t.boolean "new_manager_form_emails", default: false
      t.boolean "document_completion_emails", default: false
      t.text "preboarding_note"
      t.text "preboarding_title"
      t.boolean "onboarding_activity_notification", default: true
      t.boolean "transition_activity_notification", default: true
      t.boolean "offboarding_activity_notification", default: true
      t.integer "organization_root_id"
      t.json "role_types", default: []
      t.string "date_format", default: "mm/dd/yyyy"
      t.boolean "buddy_emails", default: false
      t.string "adp_us_company_code"
      t.boolean "enabled_calendar", default: false
      t.boolean "enabled_time_off", default: false
      t.boolean "enabled_org_chart", default: false
      t.boolean "start_date_change_emails"
      t.integer "timeout_interval", default: 10
      t.string "paylocity_integration_type"
      t.string "api_access_token"
      t.boolean "notifications_enabled", default: true
      t.boolean "is_using_custom_table", default: false
      t.json "about_section", default: {"show"=>true, "section_name"=>"About us", "section_title"=>"Let's learn the story of rocketship"}
      t.json "milestone_section", default: {"show"=>true, "section_name"=>"Our History"}
      t.json "values_section", default: {"show"=>true, "section_name"=>"Our Values"}
      t.json "team_section", default: {"show"=>true, "section_name"=>"Your Team"}
      t.json "onboard_class_section", default: {"show"=>true, "section_name"=>"Your Onboarding Class"}
      t.json "welcome_section", default: {"show"=>true, "section_name"=>"Setting you up for Success on your First Day"}
      t.json "preboarding_section", default: {"show"=>true, "section_name"=>"Congrats!"}
      t.integer "login_type", default: 0
      t.string "default_country", default: "United States"
      t.string "default_currency", default: "USD"
      t.string "token"
      t.json "calendar_permissions", default: {}
      t.json "self_signed_attributes", default: {}
      t.boolean "links_enabled", default: true
      t.jsonb "preboard_people_settings", default: {"show_team"=>true, "team_title"=>"Your Team", "show_onboard_class"=>true, "onboard_class_title"=>"Your Onboarding Class"}
      t.boolean "send_notification_before_start", default: false
      t.boolean "can_push_adp_custom_fields", default: false
      t.boolean "pull_all_workday_workers", default: false
      t.string "error_notification_emails", default: [], array: true
      t.string "adp_can_company_code"
      t.integer "hiring_type", default: 0
      t.boolean "team_digest_email", default: true
      t.string "metrics_email_job_id"
      t.string "account_state", default: "active"
      t.integer "account_type"
      t.integer "display_name_format", default: 0
      t.integer "default_email_format", default: 0
      t.integer "organization_chart_id"
      t.boolean "otp_required_for_login", default: false
      t.string "uuid"
      t.boolean "surveys_enabled", default: false
      t.index ["deleted_at"], name: "index_companies_on_deleted_at"
      t.index ["operation_contact_id"], name: "index_companies_on_operation_contact_id"
      t.index ["organization_chart_id"], name: "index_companies_on_organization_chart_id"
      t.index ["organization_root_id"], name: "index_companies_on_organization_root_id"
      t.index ["owner_id"], name: "index_companies_on_owner_id"
      t.index ["subdomain"], name: "index_companies_on_subdomain", unique: true
      t.index ["token"], name: "index_companies_on_token", unique: true
    end
    create_table "company_emails", id: :serial do |t|
      t.string "from"
      t.text "to", default: [], array: true
      t.text "cc", default: [], array: true
      t.text "subject"
      t.text "content"
      t.datetime "sent_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "bcc", default: [], array: true
      t.integer "company_id"
      t.index ["company_id"], name: "index_company_emails_on_company_id"
    end
    create_table "company_links", id: :serial do |t|
      t.string "name"
      t.string "link"
      t.integer "position"
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "location_filters", default: ["all"], array: true
      t.string "team_filters", default: ["all"], array: true
      t.string "status_filters", default: ["all"], array: true
      t.index ["company_id"], name: "index_company_links_on_company_id"
    end
    create_table "company_values", id: :serial do |t|
      t.string "name", null: false
      t.text "description", null: false
      t.integer "company_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "position", default: 0
      t.index ["company_id"], name: "index_company_values_on_company_id"
    end
    create_table "countries", id: :serial do |t|
      t.string "key"
      t.string "name"
      t.string "subdivision_type"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "areacode_type", default: "Zip"
      t.string "city_type", default: "City"
    end
    create_table "ctus_approval_chains", id: :serial do |t|
      t.integer "approval_chain_id"
      t.integer "custom_table_user_snapshot_id"
      t.integer "request_state"
      t.datetime "approval_date"
      t.integer "approved_by_id"
      t.datetime "deleted_at"
      t.index ["approval_chain_id"], name: "index_ctus_approval_chains_on_approval_chain_id"
      t.index ["custom_table_user_snapshot_id"], name: "index_ctus_approval_chains_on_custom_table_user_snapshot_id"
    end
    create_table "custom_email_alerts", id: :serial do |t|
      t.integer "company_id"
      t.integer "alert_type", default: 0
      t.integer "notified_to", default: 0
      t.string "notifiers", default: [], array: true
      t.string "title"
      t.string "subject"
      t.string "body"
      t.string "applied_to_teams", default: ["all"], array: true
      t.string "applied_to_locations", default: ["all"], array: true
      t.string "applied_to_statuses", default: ["all"], array: true
      t.integer "edited_by_id"
      t.datetime "deleted_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.boolean "is_enabled", default: true
      t.index ["company_id"], name: "index_custom_email_alerts_on_company_id"
      t.index ["deleted_at"], name: "index_custom_email_alerts_on_deleted_at"
      t.index ["edited_by_id"], name: "index_custom_email_alerts_on_edited_by_id"
    end
    create_table "custom_field_options", id: :serial do |t|
      t.integer "custom_field_id"
      t.string "option"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "namely_group_type"
      t.string "namely_group_id"
      t.integer "owner_id"
      t.integer "position", default: 0
      t.text "description"
      t.boolean "active", default: true
      t.string "workday_wid"
      t.string "adp_wfn_us_code_value"
      t.string "adp_wfn_can_code_value"
      t.string "gsuite_mapping_key"
      t.index ["custom_field_id"], name: "index_custom_field_options_on_custom_field_id"
      t.index ["namely_group_id"], name: "index_custom_field_options_on_namely_group_id"
      t.index ["namely_group_type"], name: "index_custom_field_options_on_namely_group_type"
      t.index ["owner_id"], name: "index_custom_field_options_on_owner_id"
    end
    create_table "custom_field_reports", id: :serial do |t|
      t.integer "report_id"
      t.integer "custom_field_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "position"
      t.index ["custom_field_id"], name: "index_custom_field_reports_on_custom_field_id"
      t.index ["report_id"], name: "index_custom_field_reports_on_report_id"
    end
    create_table "custom_field_values", id: :serial do |t|
      t.integer "custom_field_id"
      t.integer "user_id"
      t.text "backup_value_text"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "custom_field_option_id"
      t.integer "sub_custom_field_id"
      t.integer "coworker_id"
      t.integer "checkbox_values", default: [], array: true
      t.text "encrypted_value_text"
      t.text "encrypted_value_text_iv"
      t.datetime "deleted_at"
      t.index ["coworker_id"], name: "index_custom_field_values_on_coworker_id"
      t.index ["custom_field_id"], name: "index_custom_field_values_on_custom_field_id"
      t.index ["custom_field_option_id"], name: "index_custom_field_values_on_custom_field_option_id"
      t.index ["deleted_at"], name: "index_custom_field_values_on_deleted_at"
      t.index ["sub_custom_field_id"], name: "index_custom_field_values_on_sub_custom_field_id"
      t.index ["user_id", "custom_field_id", "deleted_at"], name: "unique_value_against_user_and_custom_field", unique: true
      t.index ["user_id"], name: "index_custom_field_values_on_user_id"
    end
    create_table "custom_fields", id: :serial do |t|
      t.integer "company_id"
      t.integer "section"
      t.integer "position"
      t.string "name"
      t.string "help_text"
      t.integer "field_type"
      t.boolean "required"
      t.boolean "required_existing"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "mapping_key"
      t.integer "integration_group", default: 0
      t.datetime "deleted_at"
      t.integer "collect_from", default: 0
      t.json "locks", default: {"all_locks"=>false}
      t.string "api_field_id"
      t.integer "custom_table_id"
      t.integer "display_location"
      t.integer "ats_integration_group"
      t.string "ats_mapping_key"
      t.integer "ats_mapping_section"
      t.string "ats_mapping_field_type"
      t.boolean "is_sensitive_field", default: false
      t.string "workday_mapping_key"
      t.text "lever_requisition_field_id"
      t.index ["company_id"], name: "index_custom_fields_on_company_id"
      t.index ["custom_table_id"], name: "index_custom_fields_on_custom_table_id"
      t.index ["deleted_at"], name: "index_custom_fields_on_deleted_at"
    end
    create_table "custom_snapshots", id: :serial do |t|
      t.integer "custom_field_id"
      t.string "custom_field_value"
      t.string "preference_field_id"
      t.integer "custom_table_user_snapshot_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["custom_field_id"], name: "index_custom_snapshots_on_custom_field_id"
      t.index ["custom_table_user_snapshot_id"], name: "index_custom_snapshots_on_custom_table_user_snapshot_id"
    end
    create_table "custom_table_user_snapshots", id: :serial do |t|
      t.integer "custom_table_id"
      t.integer "user_id"
      t.integer "edited_by_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.date "effective_date"
      t.integer "state"
      t.boolean "is_terminated", default: false
      t.json "terminated_data"
      t.integer "requester_id"
      t.integer "request_state"
      t.datetime "deleted_at"
      t.integer "integration_type"
      t.boolean "is_applicable", default: true
      t.index ["custom_table_id"], name: "index_custom_table_user_snapshots_on_custom_table_id"
      t.index ["edited_by_id"], name: "index_custom_table_user_snapshots_on_edited_by_id"
      t.index ["user_id"], name: "index_custom_table_user_snapshots_on_user_id"
    end
    create_table "custom_tables", id: :serial do |t|
      t.string "name"
      t.integer "table_type", default: 0
      t.integer "custom_table_property", default: 0
      t.integer "position"
      t.boolean "is_deletable", default: true
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.boolean "is_approval_required", default: false
      t.integer "approval_type"
      t.string "approval_ids", array: true
      t.integer "approval_expiry_time"
      t.datetime "deleted_at"
      t.index ["company_id"], name: "index_custom_tables_on_company_id"
    end
    create_table "deleted_user_emails", id: :serial do |t|
      t.string "email"
      t.string "personal_email"
      t.integer "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["user_id"], name: "index_deleted_user_emails_on_user_id"
    end
    create_table "document_connection_relations", id: :serial do |t|
      t.string "title"
      t.string "description"
      t.datetime "deleted_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["deleted_at"], name: "index_document_connection_relations_on_deleted_at", unique: true
    end
    create_table "document_upload_requests", id: :serial do |t|
      t.integer "company_id"
      t.integer "special_user_id"
      t.boolean "global"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "position"
      t.integer "user_id"
      t.datetime "deleted_at"
      t.integer "document_connection_relation_id"
      t.jsonb "meta", default: {}
      t.index ["company_id"], name: "index_document_upload_requests_on_company_id"
      t.index ["deleted_at"], name: "index_document_upload_requests_on_deleted_at"
      t.index ["document_connection_relation_id"], name: "index_doc_upload_reqs_on_doc_conn_relation_id"
      t.index ["special_user_id"], name: "index_document_upload_requests_on_special_user_id"
      t.index ["user_id"], name: "index_document_upload_requests_on_user_id"
    end
    create_table "documents", id: :serial do |t|
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "title"
      t.text "description"
      t.datetime "deleted_at"
      t.jsonb "meta", default: {}
      t.index ["company_id"], name: "index_documents_on_company_id"
      t.index ["deleted_at"], name: "index_documents_on_deleted_at"
    end
    create_table "email_templates", id: :serial do |t|
      t.integer "company_id"
      t.string "subject", null: false
      t.string "cc"
      t.string "bcc"
      t.string "description", null: false
      t.string "email_type", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "email_to"
      t.string "name"
      t.integer "invite_in"
      t.time "invite_date"
      t.integer "editor_id"
      t.boolean "is_enabled", default: true
      t.string "permission_group_ids", default: ["all"], array: true
      t.string "location_ids", default: ["all"], array: true
      t.string "department_ids", default: ["all"], array: true
      t.string "status_ids", default: ["all"], array: true
      t.string "permission_type", default: "permission_group"
      t.boolean "is_default", default: false
      t.jsonb "schedule_options", default: {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>0, "relative_key"=>nil, "duration_type"=>nil}
      t.boolean "is_temporary", default: false
      t.index ["company_id"], name: "index_email_templates_on_company_id"
    end
    create_table "employee_record_templates", id: :serial do |t|
      t.string "name", null: false
      t.string "hidden_fields", default: [], array: true
      t.integer "company_id"
      t.integer "editor_id"
      t.datetime "deleted_at"
      t.index ["company_id"], name: "index_employee_record_templates_on_company_id"
      t.index ["deleted_at"], name: "index_employee_record_templates_on_deleted_at"
      t.index ["editor_id"], name: "index_employee_record_templates_on_editor_id"
    end
    create_table "field_histories", id: :serial do |t|
      t.string "field_name"
      t.text "new_value"
      t.integer "field_changer_id"
      t.integer "custom_field_id"
      t.integer "integration_id"
      t.string "field_auditable_type"
      t.integer "field_auditable_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "field_data_type"
      t.integer "field_type"
      t.string "encrypted_new_value"
      t.string "encrypted_new_value_iv"
      t.index ["custom_field_id"], name: "index_field_histories_on_custom_field_id"
      t.index ["field_auditable_type", "field_auditable_id"], name: "field_auditable_index"
      t.index ["field_changer_id"], name: "index_field_histories_on_field_changer_id"
      t.index ["integration_id"], name: "index_field_histories_on_integration_id"
    end
    create_table "general_data_protection_regulations", id: :serial do |t|
      t.integer "edited_by_id"
      t.integer "action_type", default: 0
      t.integer "action_period", default: 1, null: false
      t.string "action_location", default: [], array: true
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["company_id"], name: "index_general_data_protection_regulations_on_company_id"
    end
    create_table "google_credentials", id: :serial do |t|
      t.json "credentials"
      t.string "credentialable_type"
      t.integer "credentialable_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
    create_table "hellosign_calls" do |t|
      t.string "api_end_point", null: false
      t.integer "state", default: 0, null: false
      t.integer "call_type", null: false
      t.integer "priority", null: false
      t.boolean "assign_now"
      t.integer "paperwork_request_id"
      t.text "paperwork_template_ids", default: [], array: true
      t.string "hellosign_bulk_request_job_id"
      t.json "user_ids"
      t.json "bulk_paperwork_requests"
      t.text "error_description"
      t.bigint "company_id"
      t.bigint "job_requester_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["company_id"], name: "index_hellosign_calls_on_company_id"
      t.index ["job_requester_id"], name: "index_hellosign_calls_on_job_requester_id"
    end
    create_table "histories", id: :serial do |t|
      t.integer "user_id"
      t.integer "company_id"
      t.string "description"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "created_by", default: 0
      t.integer "integration_type", default: 0
      t.integer "is_created", default: 0
      t.integer "description_count", default: 1
      t.integer "event_type", default: 0
      t.string "job_id"
      t.integer "email_type", default: 0
      t.datetime "schedule_email_at"
      t.integer "user_email_id"
      t.index ["company_id"], name: "index_histories_on_company_id"
      t.index ["user_id"], name: "index_histories_on_user_id"
    end
    create_table "history_users", id: :serial do |t|
      t.integer "history_id"
      t.integer "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["history_id"], name: "index_history_users_on_history_id"
      t.index ["user_id"], name: "index_history_users_on_user_id"
    end
    create_table "holidays", id: :serial do |t|
      t.string "name", null: false
      t.date "begin_date"
      t.date "end_date"
      t.boolean "multiple_dates", default: false
      t.string "team_permission_level", default: [], array: true
      t.string "location_permission_level", default: [], array: true
      t.string "status_permission_level", default: [], array: true
      t.integer "created_by_id"
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["company_id"], name: "index_holidays_on_company_id"
    end
    create_table "integration_error_slack_webhooks", id: :serial do |t|
      t.string "channel"
      t.string "webhook_url"
      t.integer "status", default: 0
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "integration_type"
    end
    create_table "integrations", id: :serial do |t|
      t.integer "company_id"
      t.string "api_name"
      t.string "backup_api_key"
      t.string "backup_secret_token"
      t.string "channel"
      t.boolean "is_enabled", default: false
      t.string "webhook_url"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "subdomain"
      t.string "backup_signature_token"
      t.string "backup_client_id"
      t.string "api_company_id"
      t.boolean "enable_create_profile", default: true
      t.string "backup_client_secret"
      t.string "company_code"
      t.string "private_key_file"
      t.string "public_key_file"
      t.string "jira_issue_statuses", default: [], array: true
      t.string "jira_complete_status", default: "Done"
      t.string "identity_provider_sso_url"
      t.text "backup_saml_certificate"
      t.string "saml_metadata_endpoint"
      t.string "backup_access_token"
      t.string "subscription_id"
      t.string "gsuite_account_url"
      t.string "gsuite_admin_email"
      t.datetime "expires_in"
      t.string "backup_refresh_token"
      t.string "gsuite_auth_code"
      t.boolean "gsuite_auth_credentials_present", default: false
      t.boolean "authentication_in_progress", default: false
      t.boolean "can_import_data", default: false
      t.string "encrypted_api_key"
      t.string "encrypted_api_key_iv"
      t.string "encrypted_secret_token"
      t.string "encrypted_secret_token_iv"
      t.string "encrypted_signature_token"
      t.string "encrypted_signature_token_iv"
      t.string "encrypted_access_token"
      t.string "encrypted_access_token_iv"
      t.string "encrypted_refresh_token"
      t.string "encrypted_refresh_token_iv"
      t.string "encrypted_client_secret"
      t.string "encrypted_client_secret_iv"
      t.string "encrypted_client_id"
      t.string "encrypted_client_id_iv"
      t.text "encrypted_saml_certificate"
      t.text "encrypted_saml_certificate_iv"
      t.string "region"
      t.boolean "enable_update_profile", default: false
      t.string "encrypted_slack_bot_access_token"
      t.string "encrypted_slack_bot_access_token_iv"
      t.string "asana_organization_id"
      t.string "asana_default_team"
      t.string "asana_personal_token"
      t.json "meta", default: {}
      t.string "iusername"
      t.string "ipassword"
      t.string "encrypted_iusername"
      t.string "encrypted_iusername_iv"
      t.string "encrypted_ipassword"
      t.string "encrypted_ipassword_iv"
      t.string "workday_human_resource_wsdl"
      t.string "jira_issue_type", default: "Task"
      t.boolean "bswift_auto_enroll", default: false
      t.string "bswift_benefit_class_code"
      t.string "bswift_group_number"
      t.string "bswift_hours_per_week"
      t.string "bswift_relation"
      t.string "bswift_hostname"
      t.string "bswift_username"
      t.string "bswift_password"
      t.string "bswift_remote_path"
      t.boolean "link_gsuite_personal_email", default: true
      t.boolean "can_export_updation", default: true
      t.boolean "enable_onboarding_templates", default: false
      t.json "onboarding_templates", default: {}
      t.string "encrypted_request_token"
      t.string "encrypted_request_token_iv"
      t.string "encrypted_request_secret"
      t.string "encrypted_request_secret_iv"
      t.string "organization_name"
      t.string "payroll_calendar_id"
      t.string "employee_group_name"
      t.string "earnings_rate_id"
      t.string "hiring_context"
      t.datetime "last_sync"
      t.boolean "can_delete_profile"
      t.boolean "can_invite_profile"
      t.string "slack_team_id"
      t.boolean "enable_company_code", default: false
      t.boolean "enable_international_templates", default: false
      t.string "last_sync_status"
      t.index ["company_id"], name: "index_integrations_on_company_id"
    end
    create_table "invites", id: :serial do |t|
      t.integer "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "token", null: false
      t.datetime "invite_at"
      t.string "subject"
      t.string "cc"
      t.string "bcc"
      t.text "description"
      t.string "job_id"
      t.datetime "deleted_at"
      t.integer "user_email_id"
      t.index ["deleted_at"], name: "index_invites_on_deleted_at"
      t.index ["token"], name: "index_invites_on_token", unique: true
      t.index ["user_email_id"], name: "index_invites_on_user_email_id"
      t.index ["user_id"], name: "index_invites_on_user_id"
    end
    create_table "job_titles", id: :serial do |t|
      t.string "name"
      t.string "adp_wfn_us_code_value"
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "adp_wfn_can_code_value"
      t.index ["company_id"], name: "index_job_titles_on_company_id"
    end
    create_table "locations", id: :serial do |t|
      t.string "name", null: false
      t.string "description"
      t.integer "company_id"
      t.integer "owner_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "users_count", default: 0
      t.datetime "deleted_at"
      t.string "adp_wfn_us_code_value"
      t.string "namely_group_type"
      t.string "namely_group_id"
      t.boolean "is_gdpr_imposed", default: false
      t.boolean "active", default: true
      t.string "adp_wfn_can_code_value"
      t.index ["company_id"], name: "index_locations_on_company_id"
      t.index ["deleted_at"], name: "index_locations_on_deleted_at"
      t.index ["name", "company_id", "deleted_at"], name: "index_locations_on_name_and_company_id_and_deleted_at", unique: true
      t.index ["namely_group_id"], name: "index_locations_on_namely_group_id"
      t.index ["namely_group_type"], name: "index_locations_on_namely_group_type"
      t.index ["owner_id"], name: "index_locations_on_owner_id"
    end
    create_table "loggings", id: :serial do |t|
      t.integer "integration_id"
      t.string "action"
      t.json "result"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "integration_name"
      t.string "api_request"
      t.integer "company_id"
      t.integer "state"
      t.index ["company_id"], name: "index_loggings_on_company_id"
      t.index ["integration_id"], name: "index_loggings_on_integration_id"
    end
    create_table "milestones", id: :serial do |t|
      t.date "happened_at"
      t.string "name", null: false
      t.text "description"
      t.integer "company_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "position", default: 0
      t.index ["company_id"], name: "index_milestones_on_company_id"
    end
    create_table "monthly_active_user_histories" do |t|
      t.datetime "date_logged", null: false
      t.integer "mau_count", default: 0, null: false
      t.bigint "company_id"
      t.index ["company_id"], name: "index_monthly_active_user_histories_on_company_id"
    end
    create_table "organization_charts", id: :serial do |t|
      t.json "chart", default: {}
      t.integer "user_ids", default: [], array: true
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["company_id"], name: "index_organization_charts_on_company_id"
    end
    create_table "paperwork_packet_connections", id: :serial do |t|
      t.integer "connectable_id"
      t.integer "paperwork_packet_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "deleted_at"
      t.string "connectable_type"
      t.index ["connectable_id"], name: "index_paperwork_packet_connections_on_connectable_id"
      t.index ["connectable_type", "connectable_id"], name: "index_paperwork_packet_connections_on_connectable"
      t.index ["deleted_at"], name: "index_paperwork_packet_connections_on_deleted_at"
      t.index ["paperwork_packet_id"], name: "index_paperwork_packet_connections_on_paperwork_packet_id"
    end
    create_table "paperwork_packets", id: :serial do |t|
      t.string "name", null: false
      t.string "description"
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "position"
      t.integer "packet_type", default: 0
      t.integer "user_id"
      t.datetime "deleted_at"
      t.jsonb "meta", default: {}
      t.index ["company_id"], name: "index_paperwork_packets_on_company_id"
      t.index ["user_id"], name: "index_paperwork_packets_on_user_id"
    end
    create_table "paperwork_requests", id: :serial do |t|
      t.integer "user_id"
      t.integer "document_id"
      t.string "hellosign_signature_id"
      t.string "hellosign_signature_request_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "state"
      t.integer "requester_id"
      t.string "signed_document"
      t.datetime "deleted_at"
      t.integer "paperwork_packet_id"
      t.integer "template_ids", default: [], array: true
      t.date "sign_date"
      t.string "unsigned_document"
      t.boolean "activity_seen", default: false
      t.integer "co_signer_id"
      t.integer "paperwork_packet_type"
      t.date "signature_completion_date"
      t.date "due_date"
      t.index ["co_signer_id"], name: "index_paperwork_requests_on_co_signer_id"
      t.index ["deleted_at"], name: "index_paperwork_requests_on_deleted_at"
      t.index ["document_id"], name: "index_paperwork_requests_on_document_id"
      t.index ["paperwork_packet_id"], name: "index_paperwork_requests_on_paperwork_packet_id"
      t.index ["paperwork_packet_type"], name: "index_paperwork_requests_on_paperwork_packet_type"
      t.index ["requester_id"], name: "index_paperwork_requests_on_requester_id"
      t.index ["user_id"], name: "index_paperwork_requests_on_user_id"
    end
    create_table "paperwork_templates", id: :serial do |t|
      t.integer "document_id"
      t.string "hellosign_template_id"
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "state"
      t.integer "position"
      t.integer "representative_id"
      t.integer "user_id"
      t.datetime "deleted_at"
      t.boolean "is_manager_representative"
      t.index ["company_id"], name: "index_paperwork_templates_on_company_id"
      t.index ["deleted_at"], name: "index_paperwork_templates_on_deleted_at"
      t.index ["document_id"], name: "index_paperwork_templates_on_document_id"
      t.index ["representative_id"], name: "index_paperwork_templates_on_representative_id"
      t.index ["user_id"], name: "index_paperwork_templates_on_user_id"
    end
    create_table "pending_hires", id: :serial do |t|
      t.string "first_name"
      t.string "last_name"
      t.string "title"
      t.string "personal_email"
      t.integer "location_id"
      t.string "phone_number"
      t.integer "team_id"
      t.string "manager"
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "start_date"
      t.string "employee_type"
      t.integer "manager_id"
      t.integer "base_salary", default: 0
      t.integer "hourly_rate", default: 0
      t.integer "bonus", default: 0
      t.string "address_line_1"
      t.string "address_line_2"
      t.string "city"
      t.string "address_state"
      t.string "zip_code"
      t.string "level"
      t.string "custom_role"
      t.string "flsa_code"
      t.json "custom_fields"
      t.integer "user_id"
      t.string "state", default: "active"
      t.datetime "deleted_at"
      t.string "google_hire_id"
      t.json "lever_custom_fields"
      t.boolean "provision_gsuite", default: true
      t.integer "send_credentials_type", default: 0
      t.integer "send_credentials_offset_before"
      t.integer "send_credentials_time", default: 8
      t.string "send_credentials_timezone"
      t.boolean "is_basic_format_custom_data", default: true
      t.string "preferred_name"
      t.string "workday_id"
      t.string "workday_id_type"
      t.json "workday_custom_fields"
      t.integer "duplication_type"
      t.string "jazz_hr_id"
      t.index ["company_id"], name: "index_pending_hires_on_company_id"
      t.index ["deleted_at"], name: "index_pending_hires_on_deleted_at"
      t.index ["location_id"], name: "index_pending_hires_on_location_id"
      t.index ["manager_id"], name: "index_pending_hires_on_manager_id"
      t.index ["team_id"], name: "index_pending_hires_on_team_id"
      t.index ["user_id"], name: "index_pending_hires_on_user_id"
    end
    create_table "personal_documents", id: :serial do |t|
      t.string "title"
      t.string "description"
      t.datetime "deleted_at"
      t.integer "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "created_by_id"
      t.index ["user_id"], name: "index_personal_documents_on_user_id"
    end
    create_table "policy_tenureships", id: :serial do |t|
      t.integer "pto_policy_id"
      t.integer "year"
      t.float "amount"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["pto_policy_id"], name: "index_policy_tenureships_on_pto_policy_id"
    end
    create_table "process_types" do |t|
      t.string "name"
      t.boolean "is_default", default: false
      t.bigint "company_id"
      t.integer "entity_type"
      t.index ["company_id"], name: "index_process_types_on_company_id"
    end
    create_table "profile_template_custom_field_connections" do |t|
      t.bigint "profile_template_id"
      t.bigint "custom_field_id"
      t.boolean "required"
      t.integer "position"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "default_field_id"
      t.datetime "deleted_at"
      t.index ["custom_field_id"], name: "field_connection_field_index"
      t.index ["profile_template_id"], name: "field_connection_template_index"
    end
    create_table "profile_template_custom_table_connections" do |t|
      t.bigint "profile_template_id"
      t.bigint "custom_table_id"
      t.integer "position"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "deleted_at"
      t.index ["custom_table_id"], name: "table_connection_field_index"
      t.index ["profile_template_id"], name: "table_connection_template_index"
    end
    create_table "profile_templates" do |t|
      t.string "name", null: false
      t.bigint "company_id"
      t.integer "edited_by_id"
      t.jsonb "meta", default: {}
      t.bigint "process_type_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "deleted_at"
      t.index ["company_id"], name: "index_profile_templates_on_company_id"
      t.index ["edited_by_id"], name: "index_profile_templates_on_edited_by_id"
      t.index ["process_type_id"], name: "index_profile_templates_on_process_type_id"
    end
    create_table "profiles", id: :serial do |t|
      t.text "about_you"
      t.string "facebook"
      t.string "twitter"
      t.string "linkedin"
      t.string "github"
      t.integer "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "deleted_at"
      t.index ["deleted_at"], name: "index_profiles_on_deleted_at"
      t.index ["user_id"], name: "index_profiles_on_user_id"
    end
    create_table "pto_adjustments", id: :serial do |t|
      t.float "hours"
      t.integer "operation"
      t.string "description"
      t.date "effective_date"
      t.integer "creator_id"
      t.boolean "is_applied", default: false
      t.integer "assigned_pto_policy_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "deleted_at"
      t.index ["assigned_pto_policy_id"], name: "index_pto_adjustments_on_assigned_pto_policy_id"
    end
    create_table "pto_balance_audit_logs", id: :serial do |t|
      t.integer "assigned_pto_policy_id"
      t.date "balance_updated_at"
      t.float "balance_added", default: 0.0
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.float "balance_used", default: 0.0
      t.text "description"
      t.integer "user_id"
      t.datetime "deleted_at"
      t.float "balance", default: 0.0
      t.index ["assigned_pto_policy_id"], name: "index_pto_balance_audit_logs_on_assigned_pto_policy_id"
      t.index ["user_id"], name: "index_pto_balance_audit_logs_on_user_id"
    end
    create_table "pto_policies", id: :serial do |t|
      t.string "name"
      t.integer "company_id"
      t.integer "policy_type"
      t.boolean "for_all_employees"
      t.boolean "unlimited_policy", default: false
      t.boolean "approved_by_manager"
      t.string "icon"
      t.jsonb "filter_policy_by"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "deleted_at"
      t.boolean "is_enabled", default: true
      t.float "accrual_rate_amount"
      t.integer "accrual_rate_unit"
      t.integer "rate_acquisition_period"
      t.integer "accrual_frequency"
      t.boolean "has_max_accrual_amount", default: false
      t.float "max_accrual_amount", default: 0.0
      t.integer "allocate_accruals_at"
      t.integer "start_of_accrual_period"
      t.integer "accrual_period_start_date"
      t.integer "accrual_renewal_time"
      t.date "accrual_renewal_date"
      t.integer "first_accrual_method"
      t.boolean "carry_over_unused_timeoff", default: true
      t.boolean "has_maximum_carry_over_amount", default: false
      t.float "maximum_carry_over_amount"
      t.boolean "can_obtain_negative_balance", default: true
      t.boolean "carry_over_negative_balance"
      t.boolean "manager_approval", default: false
      t.boolean "auto_approval", default: true
      t.boolean "expire_unused_carryover_balance", default: false
      t.date "carryover_amount_expiry_date"
      t.integer "tracking_unit", default: 0
      t.boolean "half_day_enabled", default: false
      t.float "working_hours", default: 8.0
      t.string "working_days", default: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], array: true
      t.string "unlimited_type_title", default: "Unlimited"
      t.boolean "assign_manually", default: false
      t.integer "days_to_wait_until_auto_actionable", default: 7
      t.boolean "has_maximum_increment", default: false
      t.boolean "has_minimum_increment", default: false
      t.float "maximum_increment_amount"
      t.float "minimum_increment_amount"
      t.float "maximum_negative_amount", default: 24.0
      t.integer "updated_by_id"
      t.boolean "display_detail", default: true
      t.string "xero_leave_type_id"
      t.boolean "is_paid_leave", default: true
      t.boolean "show_balance_on_pay_slip", default: false
      t.index ["company_id"], name: "index_pto_policies_on_company_id"
      t.index ["updated_by_id"], name: "index_pto_policies_on_updated_by_id"
    end
    create_table "pto_requests", id: :serial do |t|
      t.integer "user_id"
      t.boolean "partial_day_included"
      t.date "begin_date"
      t.date "end_date"
      t.text "additional_notes"
      t.integer "status", default: 0
      t.text "approval_denial_reason"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "pto_policy_id"
      t.datetime "approval_denial_date"
      t.boolean "updation_requested", default: false
      t.float "balance_hours", default: 0.0
      t.datetime "deleted_at"
      t.string "hash_id"
      t.boolean "balance_deducted", default: false
      t.integer "partner_pto_request_id"
      t.jsonb "email_options"
      t.datetime "submission_date"
      t.index ["partner_pto_request_id"], name: "index_pto_requests_on_partner_pto_request_id"
      t.index ["pto_policy_id"], name: "index_pto_requests_on_pto_policy_id"
      t.index ["user_id"], name: "index_pto_requests_on_user_id"
    end
    create_table "recommendation_feedbacks" do |t|
      t.bigint "recommendation_user_id"
      t.bigint "recommendation_owner_id"
      t.integer "itemType"
      t.integer "processType"
      t.integer "itemAction"
      t.integer "recommendedItems", default: [], array: true
      t.integer "updatedItems", default: [], array: true
      t.integer "changeReason"
      t.string "userSuggestion"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["recommendation_owner_id"], name: "index_recommendation_feedbacks_on_recommendation_owner_id"
      t.index ["recommendation_user_id"], name: "index_recommendation_feedbacks_on_recommendation_user_id"
    end
    create_table "reports", id: :serial do |t|
      t.string "name", null: false
      t.json "meta", default: {}
      t.json "permanent_fields", default: {}
      t.datetime "last_view"
      t.datetime "deleted_at"
      t.integer "user_id"
      t.integer "company_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text "gsheet_url"
      t.string "user_role_ids", default: [], array: true
      t.integer "report_type", default: 0, null: false
      t.json "custom_tables", default: {}
      t.index ["company_id"], name: "index_reports_on_company_id"
      t.index ["user_id"], name: "index_reports_on_user_id"
    end
    create_table "request_informations", id: :serial do |t|
      t.string "profile_field_ids", default: [], array: true
      t.integer "state", default: 0
      t.integer "company_id"
      t.integer "requester_id"
      t.integer "requested_to_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["company_id"], name: "index_request_informations_on_company_id"
      t.index ["requested_to_id"], name: "index_request_informations_on_requested_to_id"
      t.index ["requester_id"], name: "index_request_informations_on_requester_id"
    end
    create_table "salesforce_accounts" do |t|
      t.bigint "company_id"
      t.string "account_name"
      t.string "salesforce_id"
      t.integer "total_headcount", default: 0, null: false
      t.integer "last_week_headcount", default: 0, null: false
      t.integer "this_week_headcount", default: 0, null: false
      t.float "weekly_headcount_change", default: 0.0, null: false
      t.integer "mau", default: 0
      t.string "mrr", default: "0"
      t.boolean "cab_member", default: false
      t.date "contract_end_date"
      t.date "contract_end_notify_date"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["company_id"], name: "index_salesforce_accounts_on_company_id"
    end
    create_table "states", id: :serial do |t|
      t.string "key"
      t.string "name"
      t.integer "country_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["country_id"], name: "index_states_on_country_id"
    end
    create_table "sub_custom_fields", id: :serial do |t|
      t.integer "custom_field_id"
      t.string "name"
      t.integer "field_type"
      t.string "help_text"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["custom_field_id"], name: "index_sub_custom_fields_on_custom_field_id"
    end
    create_table "sub_task_user_connections", id: :serial do |t|
      t.integer "sub_task_id"
      t.integer "task_user_connection_id"
      t.string "state"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "deleted_at"
      t.index ["deleted_at"], name: "index_sub_task_user_connections_on_deleted_at"
      t.index ["state"], name: "index_sub_task_user_connections_on_state"
      t.index ["sub_task_id"], name: "index_sub_task_user_connections_on_sub_task_id"
      t.index ["task_user_connection_id"], name: "index_sub_task_user_connections_on_task_user_connection_id"
    end
    create_table "sub_tasks", id: :serial do |t|
      t.text "title"
      t.integer "task_id"
      t.string "state"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "deleted_at"
      t.integer "position", default: 0
      t.index ["deleted_at"], name: "index_sub_tasks_on_deleted_at"
      t.index ["state"], name: "index_sub_tasks_on_state"
      t.index ["task_id"], name: "index_sub_tasks_on_task_id"
    end
    create_table "survey_answers" do |t|
      t.bigint "survey_question_id"
      t.bigint "task_user_connection_id"
      t.string "value_text"
      t.datetime "deleted_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["survey_question_id"], name: "index_survey_answers_on_survey_question_id"
      t.index ["task_user_connection_id"], name: "index_survey_answers_on_task_user_connection_id"
    end
    create_table "survey_questions" do |t|
      t.integer "question_type"
      t.bigint "survey_id"
      t.integer "position"
      t.datetime "deleted_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "question_text"
      t.index ["survey_id"], name: "index_survey_questions_on_survey_id"
    end
    create_table "surveys" do |t|
      t.bigint "company_id"
      t.integer "survey_type"
      t.text "name"
      t.integer "estimated_time"
      t.datetime "deleted_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["company_id"], name: "index_surveys_on_company_id"
    end
    create_table "task_user_connections", id: :serial do |t|
      t.integer "user_id"
      t.integer "task_id"
      t.string "state"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "owner_id"
      t.date "due_date"
      t.boolean "activity_seen", default: false
      t.boolean "is_custom_due_date", default: false
      t.string "token"
      t.datetime "deleted_at"
      t.integer "jira_issue_id"
      t.date "from_due_date"
      t.date "before_due_date"
      t.integer "schedule_days_gap", default: 0
      t.integer "workspace_id"
      t.integer "owner_type", default: 0
      t.boolean "is_offboarding_task", default: false
      t.datetime "completed_at"
      t.string "asana_id"
      t.boolean "send_to_asana"
      t.integer "completed_by_method", default: 0
      t.date "completion_date"
      t.string "asana_webhook_gid"
      t.index ["deleted_at"], name: "index_task_user_connections_on_deleted_at"
      t.index ["owner_id"], name: "index_task_user_connections_on_owner_id"
      t.index ["state"], name: "index_task_user_connections_on_state"
      t.index ["task_id"], name: "index_task_user_connections_on_task_id"
      t.index ["user_id"], name: "index_task_user_connections_on_user_id"
      t.index ["workspace_id"], name: "index_task_user_connections_on_workspace_id"
    end
    create_table "tasks", id: :serial do |t|
      t.integer "workstream_id"
      t.string "name"
      t.text "description"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "owner_id"
      t.integer "deadline_in"
      t.integer "position"
      t.string "task_type"
      t.datetime "deleted_at"
      t.integer "time_line", default: 0
      t.integer "before_deadline_in", default: 0
      t.integer "workspace_id"
      t.string "sanitized_name"
      t.integer "custom_field_id"
      t.jsonb "task_schedule_options", default: {"due_date_timeline"=>nil, "assign_on_timeline"=>nil, "due_date_custom_date"=>nil, "assign_on_custom_date"=>nil, "due_date_relative_key"=>nil, "assign_on_relative_key"=>nil}
      t.bigint "survey_id"
      t.index ["custom_field_id"], name: "index_tasks_on_custom_field_id"
      t.index ["deleted_at"], name: "index_tasks_on_deleted_at"
      t.index ["owner_id"], name: "index_tasks_on_owner_id"
      t.index ["survey_id"], name: "index_tasks_on_survey_id"
      t.index ["workspace_id"], name: "index_tasks_on_workspace_id"
      t.index ["workstream_id"], name: "index_tasks_on_workstream_id"
    end
    create_table "teams", id: :serial do |t|
      t.string "name", null: false
      t.string "description"
      t.integer "company_id"
      t.integer "owner_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "users_count", default: 0
      t.string "adp_wfn_us_code_value"
      t.string "namely_group_type"
      t.string "namely_group_id"
      t.boolean "active", default: true
      t.string "adp_wfn_can_code_value"
      t.index ["company_id"], name: "index_teams_on_company_id"
      t.index ["name", "company_id"], name: "index_teams_on_name_and_company_id", unique: true
      t.index ["namely_group_id", "namely_group_type"], name: "index_teams_on_namely_group_id_and_namely_group_type"
      t.index ["owner_id"], name: "index_teams_on_owner_id"
    end
    create_table "termination_emails", id: :serial do |t|
      t.datetime "send_at"
      t.string "subject"
      t.string "cc"
      t.string "bcc"
      t.text "description"
      t.integer "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["user_id"], name: "index_termination_emails_on_user_id"
    end
    create_table "unassigned_pto_policies", id: :serial do |t|
      t.integer "user_id"
      t.integer "pto_policy_id"
      t.date "effective_date"
      t.float "starting_balance"
      t.datetime "deleted_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["pto_policy_id"], name: "index_unassigned_pto_policies_on_pto_policy_id"
      t.index ["user_id"], name: "index_unassigned_pto_policies_on_user_id"
    end
    create_table "uploaded_files", id: :serial do |t|
      t.integer "entity_id"
      t.string "entity_type"
      t.string "file"
      t.string "type", null: false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "company_id"
      t.string "original_filename"
      t.integer "position", default: 0
      t.datetime "deleted_at"
      t.index ["company_id"], name: "index_uploaded_files_on_company_id"
      t.index ["deleted_at"], name: "index_uploaded_files_on_deleted_at"
      t.index ["entity_id", "entity_type"], name: "index_uploaded_files_on_entity_id_and_entity_type"
    end
    create_table "user_document_connections", id: :serial do |t|
      t.integer "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "state", default: "request"
      t.integer "company_id"
      t.datetime "deleted_at"
      t.integer "created_by_id"
      t.integer "document_connection_relation_id"
      t.integer "packet_id"
      t.date "due_date"
      t.index ["company_id"], name: "index_user_document_connections_on_company_id"
      t.index ["deleted_at"], name: "index_user_document_connections_on_deleted_at"
      t.index ["document_connection_relation_id"], name: "index_user_doc_conns_on_doc_conn_relation_id"
      t.index ["user_id"], name: "index_user_document_connections_on_user_id"
    end
    create_table "user_emails", id: :serial do |t|
      t.string "subject"
      t.string "cc"
      t.string "bcc"
      t.string "description"
      t.datetime "invite_at"
      t.integer "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "email_status"
      t.string "email_type"
      t.datetime "sent_at"
      t.string "template_name"
      t.string "message_id"
      t.json "activity", default: {"status"=>nil, "opens"=>nil}
      t.integer "editor_id"
      t.datetime "deleted_at"
      t.jsonb "schedule_options", default: {"due"=>nil, "date"=>nil, "time"=>nil, "duration"=>nil, "send_email"=>nil, "relative_key"=>nil, "duration_type"=>nil}
      t.string "job_id"
      t.string "from"
      t.integer "scheduled_from"
      t.jsonb "template_attachments", default: [], array: true
      t.string "to", default: [], array: true
      t.index ["user_id"], name: "index_user_emails_on_user_id"
    end
    create_table "user_roles", id: :serial do |t|
      t.string "name", null: false
      t.json "permissions", default: {}
      t.integer "company_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.boolean "is_account_owner", default: false
      t.integer "role_type", default: 0, null: false
      t.integer "position", default: 0, null: false
      t.text "description"
      t.integer "temp_team_permission_level"
      t.integer "temp_location_permission_level"
      t.string "temp_status_permission_level"
      t.integer "reporting_level", default: 1
      t.boolean "is_default", default: false
      t.string "team_permission_level", default: [], array: true
      t.string "location_permission_level", default: [], array: true
      t.string "status_permission_level", default: [], array: true
      t.index ["company_id"], name: "index_user_roles_on_company_id"
    end
    create_table "users", id: :serial do |t|
      t.integer "company_id"
      t.string "email"
      t.string "personal_email"
      t.string "first_name", null: false
      t.string "last_name", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "team_id"
      t.integer "location_id"
      t.string "provider", default: "email", null: false
      t.string "uid", default: "", null: false
      t.string "encrypted_password", default: "", null: false
      t.string "reset_password_token"
      t.datetime "reset_password_sent_at"
      t.datetime "remember_created_at"
      t.integer "sign_in_count", default: 0, null: false
      t.datetime "current_sign_in_at"
      t.datetime "last_sign_in_at"
      t.string "current_sign_in_ip"
      t.string "last_sign_in_ip"
      t.string "confirmation_token"
      t.datetime "confirmed_at"
      t.datetime "confirmation_sent_at"
      t.string "unconfirmed_email"
      t.json "tokens"
      t.integer "role", default: 0, null: false
      t.date "start_date"
      t.integer "manager_id"
      t.string "title"
      t.string "state", default: "active"
      t.datetime "deleted_at"
      t.integer "outstanding_tasks_count", default: 0, null: false
      t.integer "onboard_email"
      t.integer "tasks_count", default: 0, null: false
      t.date "termination_date"
      t.integer "bamboo_id"
      t.string "last_changed"
      t.integer "incomplete_paperwork_count", default: 0, null: false
      t.integer "buddy_id"
      t.integer "current_stage", default: 8
      t.integer "user_document_connections_count", default: 0, null: false
      t.boolean "super_user", default: false
      t.string "namely_id"
      t.integer "incomplete_upload_request_count", default: 0
      t.string "adp_wfn_us_id"
      t.integer "outstanding_owner_tasks_count", default: 0
      t.boolean "document_seen", default: false
      t.string "preferred_name"
      t.integer "failed_attempts", default: 0, null: false
      t.string "unlock_token"
      t.datetime "locked_at"
      t.integer "created_by_id"
      t.json "preboarding_progress"
      t.integer "is_form_completed_by_manager", default: 0
      t.integer "account_creator_id"
      t.integer "co_signer_paperwork_count", default: 0
      t.string "namely_last_changed"
      t.boolean "onboarding_completed", default: false
      t.integer "created_by_source", default: 0
      t.integer "waiting_for_documents", default: [], array: true
      t.string "job_tier"
      t.string "gsuite_initial_password"
      t.boolean "gsuite_account_exists", default: false
      t.boolean "google_account_credentials_sent", default: false
      t.integer "user_role_id"
      t.date "last_day_worked"
      t.integer "termination_type"
      t.integer "eligible_for_rehire"
      t.string "preboarding_invisible_field_ids", default: [], array: true
      t.integer "onboarding_progress", default: 0
      t.string "preferred_full_name"
      t.boolean "paylocity_onboard", default: false
      t.string "last_logged_in_email"
      t.datetime "fields_last_modified_at"
      t.json "calendar_preferences", default: {}
      t.string "okta_id"
      t.integer "one_login_id"
      t.date "old_start_date"
      t.boolean "is_gdpr_action_taken", default: false
      t.date "gdpr_action_date"
      t.string "guid"
      t.boolean "slack_notification", default: false
      t.boolean "email_notification", default: true
      t.string "paylocity_id"
      t.boolean "deletion_through_gdpr", default: false
      t.datetime "last_active"
      t.string "manager_form_token"
      t.boolean "provision_gsuite", default: true
      t.integer "send_credentials_type", default: 0
      t.integer "send_credentials_offset_before"
      t.integer "send_credentials_time", default: 8
      t.string "send_credentials_timezone"
      t.boolean "is_rehired", default: false
      t.string "request_information_form_token"
      t.string "asana_id"
      t.string "workday_id"
      t.datetime "expires_in"
      t.string "workday_id_type"
      t.boolean "sent_to_bswift", default: false
      t.string "adp_wfn_can_id"
      t.boolean "is_terminated_in_bswift", default: false
      t.string "adp_onboarding_template"
      t.string "xero_id"
      t.string "adp_work_assignment_id"
      t.string "hash_id"
      t.integer "remove_access_timing", default: 0
      t.date "remove_access_date"
      t.integer "remove_access_time", default: 1
      t.string "remove_access_timezone"
      t.string "deputy_id"
      t.date "last_offboarding_event_date"
      t.string "fifteen_five_id"
      t.string "active_directory_object_id"
      t.string "active_directory_initial_password"
      t.boolean "adfs_account_credentials_sent", default: false
      t.boolean "seen_profile_setup", default: false
      t.bigint "onboarding_profile_template_id"
      t.string "paychex_id"
      t.bigint "offboarding_profile_template_id"
      t.boolean "seen_documents_v2", default: false
      t.boolean "smart_assignment", default: false
      t.string "encrypted_otp_secret"
      t.string "encrypted_otp_secret_iv"
      t.string "encrypted_otp_secret_salt"
      t.integer "consumed_timestep"
      t.boolean "otp_required_for_login", default: false
      t.boolean "show_qr_code", default: true
      t.string "peakon_id"
      t.string "gsuite_id"
      t.string "last_used_profile_template_id"
      t.string "trinet_id"
      t.string "slack_id"
      t.index ["account_creator_id"], name: "index_users_on_account_creator_id"
      t.index ["buddy_id"], name: "index_users_on_buddy_id"
      t.index ["company_id", "email", "deleted_at"], name: "index_users_on_company_id_and_email_and_deleted_at", unique: true
      t.index ["company_id", "personal_email"], name: "index_users_on_company_id_and_personal_email"
      t.index ["company_id"], name: "index_users_on_company_id"
      t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
      t.index ["deleted_at"], name: "index_users_on_deleted_at"
      t.index ["location_id"], name: "index_users_on_location_id"
      t.index ["manager_form_token"], name: "index_users_on_manager_form_token", unique: true
      t.index ["manager_id"], name: "index_users_on_manager_id"
      t.index ["offboarding_profile_template_id"], name: "index_users_on_offboarding_profile_template_id"
      t.index ["onboarding_profile_template_id"], name: "index_users_on_onboarding_profile_template_id"
      t.index ["request_information_form_token"], name: "index_users_on_request_information_form_token", unique: true
      t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
      t.index ["team_id"], name: "index_users_on_team_id"
      t.index ["uid", "provider", "company_id", "deleted_at"], name: "index_users_on_uid_and_provider_and_company_id_and_deleted_at", unique: true
      t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
      t.index ["user_role_id"], name: "index_users_on_user_role_id"
    end
    create_table "versions", id: :serial do |t|
      t.string "item_type", null: false
      t.integer "item_id", null: false
      t.string "event", null: false
      t.string "whodunnit"
      t.text "object"
      t.datetime "created_at"
      t.string "ip"
      t.string "user_agent"
      t.string "company_name"
      t.text "object_changes"
      t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    end
    create_table "webhooks", id: :serial do |t|
      t.json "response_data"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "integeration_name"
      t.string "action"
      t.integer "status", default: 0, null: false
      t.integer "company_id"
      t.index ["company_id"], name: "index_webhooks_on_company_id"
    end
    create_table "workspace_images", id: :serial do |t|
      t.string "image"
    end
    create_table "workspace_members", id: :serial do |t|
      t.integer "member_id"
      t.integer "workspace_id"
      t.integer "member_role", default: 0
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["member_id"], name: "index_workspace_members_on_member_id"
      t.index ["workspace_id"], name: "index_workspace_members_on_workspace_id"
    end
    create_table "workspaces", id: :serial do |t|
      t.string "name"
      t.string "time_zone", default: "Pacific Time (US & Canada)", null: false
      t.string "associated_email"
      t.integer "company_id"
      t.integer "workspace_image_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "deleted_at"
      t.integer "created_by"
      t.boolean "notification_all", default: true
      t.json "notification_ids", default: []
      t.index ["company_id"], name: "index_workspaces_on_company_id"
      t.index ["deleted_at"], name: "index_workspaces_on_deleted_at"
      t.index ["name"], name: "index_workspaces_on_name"
      t.index ["workspace_image_id"], name: "index_workspaces_on_workspace_image_id"
    end
    create_table "workstreams", id: :serial do |t|
      t.integer "company_id"
      t.string "name"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "tasks_count", default: 0
      t.integer "position"
      t.datetime "deleted_at"
      t.jsonb "meta", default: {}
      t.bigint "updated_by_id"
      t.bigint "process_type_id"
      t.string "sort_type", default: "assignee_a_z"
      t.index ["company_id"], name: "index_workstreams_on_company_id"
      t.index ["deleted_at"], name: "index_workstreams_on_deleted_at"
      t.index ["process_type_id"], name: "index_workstreams_on_process_type_id"
      t.index ["updated_by_id"], name: "index_workstreams_on_updated_by_id"
    end
    add_foreign_key "adp_subscription_users", "adp_subscriptions"
    add_foreign_key "anonymized_data", "users"
    add_foreign_key "api_keys", "companies"
    add_foreign_key "api_loggings", "companies"
    add_foreign_key "calendar_feeds", "companies"
    add_foreign_key "calendar_feeds", "users"
    add_foreign_key "companies", "organization_charts"
    add_foreign_key "companies", "users", column: "operation_contact_id"
    add_foreign_key "companies", "users", column: "organization_root_id"
    add_foreign_key "companies", "users", column: "owner_id", on_delete: :nullify
    add_foreign_key "company_links", "companies"
    add_foreign_key "company_values", "companies", on_delete: :cascade
    add_foreign_key "custom_email_alerts", "companies"
    add_foreign_key "custom_field_options", "users", column: "owner_id"
    add_foreign_key "custom_field_values", "custom_fields"
    add_foreign_key "custom_field_values", "users"
    add_foreign_key "custom_field_values", "users", column: "coworker_id"
    add_foreign_key "custom_fields", "companies"
    add_foreign_key "custom_snapshots", "custom_fields"
    add_foreign_key "custom_snapshots", "custom_table_user_snapshots"
    add_foreign_key "custom_table_user_snapshots", "custom_tables"
    add_foreign_key "custom_table_user_snapshots", "users"
    add_foreign_key "custom_table_user_snapshots", "users", column: "requester_id"
    add_foreign_key "custom_tables", "companies"
    add_foreign_key "deleted_user_emails", "users"
    add_foreign_key "document_upload_requests", "companies"
    add_foreign_key "document_upload_requests", "document_connection_relations"
    add_foreign_key "email_templates", "companies"
    add_foreign_key "employee_record_templates", "companies"
    add_foreign_key "employee_record_templates", "users", column: "editor_id"
    add_foreign_key "general_data_protection_regulations", "companies"
    add_foreign_key "hellosign_calls", "companies"
    add_foreign_key "hellosign_calls", "users", column: "job_requester_id"
    add_foreign_key "histories", "companies"
    add_foreign_key "histories", "users"
    add_foreign_key "history_users", "histories"
    add_foreign_key "history_users", "users"
    add_foreign_key "holidays", "companies"
    add_foreign_key "integrations", "companies"
    add_foreign_key "invites", "user_emails"
    add_foreign_key "invites", "users"
    add_foreign_key "job_titles", "companies"
    add_foreign_key "locations", "companies"
    add_foreign_key "locations", "users", column: "owner_id"
    add_foreign_key "loggings", "companies"
    add_foreign_key "loggings", "integrations"
    add_foreign_key "milestones", "companies", on_delete: :cascade
    add_foreign_key "monthly_active_user_histories", "companies"
    add_foreign_key "organization_charts", "companies"
    add_foreign_key "paperwork_packet_connections", "paperwork_packets"
    add_foreign_key "paperwork_packets", "companies"
    add_foreign_key "paperwork_requests", "paperwork_packets"
    add_foreign_key "paperwork_requests", "users", column: "co_signer_id"
    add_foreign_key "pending_hires", "companies"
    add_foreign_key "pending_hires", "users"
    add_foreign_key "personal_documents", "users"
    add_foreign_key "personal_documents", "users", column: "created_by_id"
    add_foreign_key "policy_tenureships", "pto_policies"
    add_foreign_key "process_types", "companies"
    add_foreign_key "profile_template_custom_field_connections", "custom_fields"
    add_foreign_key "profile_template_custom_field_connections", "profile_templates"
    add_foreign_key "profile_template_custom_table_connections", "custom_tables"
    add_foreign_key "profile_template_custom_table_connections", "profile_templates"
    add_foreign_key "profile_templates", "companies"
    add_foreign_key "profile_templates", "process_types"
    add_foreign_key "pto_adjustments", "assigned_pto_policies"
    add_foreign_key "pto_balance_audit_logs", "assigned_pto_policies"
    add_foreign_key "pto_balance_audit_logs", "users"
    add_foreign_key "pto_policies", "users", column: "updated_by_id"
    add_foreign_key "recommendation_feedbacks", "users", column: "recommendation_owner_id"
    add_foreign_key "recommendation_feedbacks", "users", column: "recommendation_user_id"
    add_foreign_key "reports", "companies"
    add_foreign_key "reports", "users"
    add_foreign_key "request_informations", "companies"
    add_foreign_key "request_informations", "users", column: "requested_to_id"
    add_foreign_key "request_informations", "users", column: "requester_id"
    add_foreign_key "salesforce_accounts", "companies"
    add_foreign_key "states", "countries"
    add_foreign_key "sub_custom_fields", "custom_fields"
    add_foreign_key "sub_task_user_connections", "sub_tasks"
    add_foreign_key "sub_task_user_connections", "task_user_connections"
    add_foreign_key "sub_tasks", "tasks"
    add_foreign_key "survey_answers", "survey_questions"
    add_foreign_key "survey_answers", "task_user_connections"
    add_foreign_key "survey_questions", "surveys"
    add_foreign_key "surveys", "companies"
    add_foreign_key "task_user_connections", "tasks"
    add_foreign_key "task_user_connections", "users"
    add_foreign_key "task_user_connections", "workspaces"
    add_foreign_key "tasks", "custom_fields"
    add_foreign_key "tasks", "surveys"
    add_foreign_key "tasks", "users", column: "owner_id"
    add_foreign_key "tasks", "workspaces"
    add_foreign_key "tasks", "workstreams"
    add_foreign_key "teams", "companies"
    add_foreign_key "teams", "users", column: "owner_id"
    add_foreign_key "uploaded_files", "companies"
    add_foreign_key "user_document_connections", "document_connection_relations"
    add_foreign_key "user_document_connections", "users"
    add_foreign_key "user_document_connections", "users", column: "created_by_id"
    add_foreign_key "user_emails", "users"
    add_foreign_key "user_roles", "companies"
    add_foreign_key "users", "companies"
    add_foreign_key "users", "locations"
    add_foreign_key "users", "profile_templates", column: "offboarding_profile_template_id"
    add_foreign_key "users", "profile_templates", column: "onboarding_profile_template_id"
    add_foreign_key "users", "teams"
    add_foreign_key "users", "users", column: "account_creator_id"
    add_foreign_key "users", "users", column: "buddy_id"
    add_foreign_key "users", "users", column: "manager_id"
    add_foreign_key "webhooks", "companies"
    add_foreign_key "workspaces", "companies"
    add_foreign_key "workspaces", "workspace_images"
    add_foreign_key "workstreams", "companies"
    add_foreign_key "workstreams", "users", column: "updated_by_id"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The initial migration is not revertable"
  end
end
