class CreateCustomSections < ActiveRecord::Migration[5.1]
  def change
    create_table :custom_sections do |t|
      t.integer :section
      t.boolean :is_approval_required, default: false
      t.integer :approval_expiry_time
      t.references :company, foreign_key: true
      t.timestamps
    end
  end
end
