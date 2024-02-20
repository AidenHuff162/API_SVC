class AddMetaFieldToEmailTemplates < ActiveRecord::Migration[5.1]
  def change
    add_column :email_templates, :meta, :jsonb, default: {}
  end
end
