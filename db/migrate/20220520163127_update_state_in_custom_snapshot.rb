class UpdateStateInCustomSnapshot < ActiveRecord::Migration[5.1]
  def change
    Rails.logger.debug '----- Update Existing Custom Snapshots Custom Field Value Migration Started -----'
    begin
      custom_snapshot = CustomSnapshot.includes(custom_table_user_snapshot: :user)
                                      .where(preference_field_id: 'st', custom_field_value: nil)
                                      .where.not(custom_table_user_snapshots: { state: 'processed' })

      Rails.logger.debug "Total number of Custom Snapshots which are going to be updated: #{custom_snapshot.count}"
      custom_snapshot.find_each.with_index do |cs, index|
        cs.update_column(:custom_field_value, cs.custom_table_user_snapshot.user.state)
        Rails.logger.debug "Custom Snapshot with id #{cs.id} which is present on index #{index} is updated"
      end
      Rails.logger.debug '----- Update Existing Custom Snapshots Custom Field Value Migration Completed -----'
    rescue
      Rails.logger.debug '----- Update Existing Custom Snapshots Custom Field Value Migration Failed -----'
    end
  end
end
