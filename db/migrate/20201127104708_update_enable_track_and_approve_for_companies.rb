class UpdateEnableTrackAndApproveForCompanies < ActiveRecord::Migration[5.1]
  def change
    Company.where(is_using_custom_table: true).update_all(enable_custom_table_approval_engine: true)
  end
end
