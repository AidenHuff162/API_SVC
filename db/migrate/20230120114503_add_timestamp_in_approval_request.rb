class AddTimestampInApprovalRequest < ActiveRecord::Migration[6.0]
  def change
    add_timestamps :approval_requests, null: true
  end
end
