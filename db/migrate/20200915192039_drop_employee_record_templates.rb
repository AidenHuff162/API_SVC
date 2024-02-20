class DropEmployeeRecordTemplates < ActiveRecord::Migration[5.1]
  def change
    drop_table :employee_record_templates
  end
end
