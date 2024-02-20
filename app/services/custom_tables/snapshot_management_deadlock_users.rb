class CustomTables::SnapshotManagementDeadlockUsers

  def perform
    CustomTable.joins(:company).where(custom_table_property: :role_information, table_type: :timeline, companies: {account_state: :active}).find_each(batch_size: 30) do |custom_table|
      company = custom_table.company
      custom_table_user_snapshots = fetch_role_information_ctus(custom_table, company)

      custom_table_user_snapshots.try(:each) do |ctus|
        ::CustomTables::AssignMismatchCustomFieldValue.new(ctus).perform
      end
    end
  end

  private

  def fetch_role_information_ctus(custom_table, company)
    current_time = company.time
    CustomTableUserSnapshot.where("state = ? AND custom_table_id = ? AND is_applicable = ? AND (updated_at between ? AND ?)", CustomTableUserSnapshot.states[:applied],  custom_table.id, true, current_time - 6.hours, current_time).order( updated_at: :desc)
  end
end
