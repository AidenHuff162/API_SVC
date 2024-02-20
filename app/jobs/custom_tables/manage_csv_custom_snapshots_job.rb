module CustomTables
  class ManageCsvCustomSnapshotsJob < ApplicationJob
    queue_as :manage_csv_custom_snapshots

    def perform(custom_table_user_snapshot)
      ::CustomTables::AssignCustomFieldValue.new.assign_values_to_user(custom_table_user_snapshot)
    end
  end
end
