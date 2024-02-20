class CreateCsApprovalChains < ActiveRecord::Migration[5.1]
  def change
    create_table :cs_approval_chains do |t|
      t.integer "approver_id"
      t.boolean "current_approver", default: false
      t.integer "state"
      t.date "approval_date"
      t.integer "custom_section_approval_id"
      t.integer "approval_chain_id"
      t.datetime "deleted_at"
      t.index ["custom_section_approval_id"], name: "index_cs_approval_chains_on_custom_section_approval_id"
      t.index ["approval_chain_id"], name: "index_cs_approval_chains_on_approval_chain_id"

      t.timestamps
    end
  end
end
