class SetDefaultNotificationSettingForCompany < ActiveRecord::Migration[6.0]
  def change
    change_column_default :companies, :notifications_enabled, false
  end
end
