class AddTimestampToCtusApprovalChain < ActiveRecord::Migration[5.1]
  def change
    add_column :ctus_approval_chains, :created_at, :datetime
    add_column :ctus_approval_chains, :updated_at, :datetime
  end
end
