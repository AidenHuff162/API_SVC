module CustomTables
  class ManageCustomTableUserSnapshots < ApplicationJob
    queue_as :manage_custom_table_user_snapshots

    def perform(custom_table_id)
      custom_table = CustomTable.find_by(id: custom_table_id)
      ::CustomTables::SnapshotManagement.new.assign_ctus_values_to_users(custom_table) if custom_table.present? && custom_table.timeline? && custom_table.company.present?
    end
  end
end
