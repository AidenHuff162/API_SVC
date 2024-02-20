class AddHellosignBulkResponseStatusInHellosignCallTable < ActiveRecord::Migration[6.0]
  def change
    add_column :hellosign_calls, :hellosign_bulk_response_status, :json , default: {}
  end
end
