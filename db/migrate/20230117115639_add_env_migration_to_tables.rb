class AddEnvMigrationToTables < ActiveRecord::Migration[6.0]
  def change
    add_column :activities, :env_migration, :string, default: nil
    add_column :approval_chains, :env_migration, :string, default: nil
    add_column :approval_requests, :env_migration, :string, default: nil
    add_column :assigned_pto_policies, :env_migration, :string, default: nil
    add_column :cs_approval_chains, :env_migration, :string, default: nil
    add_column :ctus_approval_chains, :env_migration, :string, default: nil
    add_column :custom_field_options, :env_migration, :string, default: nil
    add_column :custom_field_reports, :env_migration, :string, default: nil
    add_column :custom_field_values, :env_migration, :string, default: nil
    add_column :custom_section_approvals, :env_migration, :string, default: nil
    add_column :custom_snapshots, :env_migration, :string, default: nil
    add_column :custom_table_user_snapshots, :env_migration, :string, default: nil
    add_column :document_connection_relations, :env_migration, :string, default: nil
    add_column :field_histories, :env_migration, :string, default: nil
    add_column :google_credentials, :env_migration, :string, default: nil
    add_column :history_users, :env_migration, :string, default: nil
    add_column :integration_credentials, :env_migration, :string, default: nil
    add_column :integration_field_mappings, :env_migration, :string, default: nil
    add_column :paperwork_packet_connections, :env_migration, :string, default: nil
    add_column :paperwork_requests, :env_migration, :string, default: nil
    add_column :personal_documents, :env_migration, :string, default: nil
    add_column :policy_tenureships, :env_migration, :string, default: nil
    add_column :profile_template_custom_field_connections, :env_migration, :string, default: nil
    add_column :profile_template_custom_table_connections, :env_migration, :string, default: nil
    add_column :pto_balance_audit_logs, :env_migration, :string, default: nil
    add_column :pto_adjustments, :env_migration, :string, default: nil
    add_column :pto_requests, :env_migration, :string, default: nil
    add_column :requested_fields, :env_migration, :string, default: nil
    add_column :sub_tasks, :env_migration, :string, default: nil
    add_column :sub_task_user_connections, :env_migration, :string, default: nil
    add_column :survey_answers, :env_migration, :string, default: nil
    add_column :survey_questions, :env_migration, :string, default: nil
    add_column :tasks, :env_migration, :string, default: nil
    add_column :task_user_connections, :env_migration, :string, default: nil
    add_column :unassigned_pto_policies, :env_migration, :string, default: nil
    add_column :user_emails, :env_migration, :string, default: nil
    add_column :workspace_members, :env_migration, :string, default: nil
  end
end
