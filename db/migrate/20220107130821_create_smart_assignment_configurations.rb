class CreateSmartAssignmentConfigurations < ActiveRecord::Migration[5.1]
  def change
    create_table :smart_assignment_configurations do |t|
      t.jsonb :meta , default: {}
      t.references :company, foreign_key: true

      t.timestamps
    end
  end
end
