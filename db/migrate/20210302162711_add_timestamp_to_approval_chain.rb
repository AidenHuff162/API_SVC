class AddTimestampToApprovalChain < ActiveRecord::Migration[5.1]
  def change
    add_column :approval_chains, :created_at, :datetime
    add_column :approval_chains, :updated_at, :datetime
    add_column :approval_chains, :deleted_at, :datetime
  end
end
