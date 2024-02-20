class UpdateMultipleInstance < ActiveRecord::Migration[5.1]
  def change
    IntegrationInventory.find_by(api_identifier: 'xero')&.update(enable_multiple_instance: false)
  end
end
