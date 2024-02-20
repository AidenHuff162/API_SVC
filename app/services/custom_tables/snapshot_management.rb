class CustomTables::SnapshotManagement

  def manage_timeline_snapshots_overnight
    CustomTable.where(table_type: CustomTable.table_types[:timeline]).find_each(batch_size: 30) do |custom_table|
      ::CustomTables::ManageCustomTableUserSnapshots.perform_later(custom_table.id)
    end
  end

  def assign_ctus_values_to_users(custom_table)
    custom_table_user_snapshots = fetch_grouped_ctus_by_user_id(custom_table)
    previous_user_id = nil

    custom_table_user_snapshots.try(:each) do |key, value|
      value.try(:each) do |custom_table_user_snapshot|
        if custom_table_user_snapshot.user_id != previous_user_id
          previous_user_id = custom_table_user_snapshot.user_id
          custom_table_user_snapshot.update_column(:state, CustomTableUserSnapshot.states[:applied])
          ::CustomTables::ManageCustomSnapshotsJob.perform_later(custom_table_user_snapshot.reload)
          update_previous_custom_table_user_snapshots(custom_table, custom_table_user_snapshot.user_id, custom_table_user_snapshot.id)
        else
          custom_table_user_snapshot.update_column(:state, CustomTableUserSnapshot.states[:processed])
        end
      end
    end
  end

  private

  def fetch_current_timeline_ctus(custom_table)
    company = custom_table.company
    current_date = DateTime.now.utc.in_time_zone(company.time_zone).to_date
    custom_table.custom_table_user_snapshots.where('DATE(effective_date) = ? AND state = ? AND (request_state IS NULL OR request_state = ?) AND is_applicable = ?', current_date, CustomTableUserSnapshot.states[:queue], CustomTableUserSnapshot.request_states[:approved], true).order(effective_date: :desc, updated_at: :desc)
  end

  def fetch_grouped_ctus_by_user_id(custom_table)
    results = fetch_current_timeline_ctus(custom_table)
    results.to_a.group_by(&:user_id) if results.present?
  end

  def update_previous_custom_table_user_snapshots(custom_table, user_id, current_timeline_ctus_id)
    custom_table.custom_table_user_snapshots.where('NOT(id = ?) AND DATE(effective_date) <= ? AND user_id = ? AND is_applicable = ?', current_timeline_ctus_id, DateTime.now.utc.in_time_zone(custom_table.company.time_zone).to_date, user_id, true).update_all(state:  CustomTableUserSnapshot.states[:processed])
  end
end
