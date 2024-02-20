class CreateCustomSectionApprovals < ActiveRecord::Migration[5.1]
  def change
    create_table :custom_section_approvals do |t|
      t.integer "custom_section_id"
      t.integer "user_id"
      t.integer "requester_id"
      t.integer "state"
      t.datetime "deleted_at"
      t.index ["custom_section_id"], name: "index_custom_section_approvals_on_custom_section_id"
      t.index ["requester_id"], name: "index_custom_section_approvals_on_requester_id"
      t.index ["user_id"], name: "index_custom_section_approvals_on_user_id"
      t.timestamps
    end
  end
end
