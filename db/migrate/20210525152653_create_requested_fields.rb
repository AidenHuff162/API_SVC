class CreateRequestedFields < ActiveRecord::Migration[5.1]
  def change
    create_table :requested_fields do |t|
      t.integer "custom_section_approval_id"
      t.integer "custom_field_id"
      t.jsonb "custom_field_value"
      t.integer "field_type"
      t.string "preference_field_id"
      t.datetime "deleted_at"
      t.index ["custom_field_id"], name: "index_requested_fields_on_custom_field_id"
      t.index ["custom_section_approval_id"], name: "index_requested_fields_on_custom_section_approval_id"

      t.timestamps
    end
  end
end
