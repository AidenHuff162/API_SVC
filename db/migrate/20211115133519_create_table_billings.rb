class CreateTableBillings < ActiveRecord::Migration[5.1]
  def change
    create_table :billings do |t|
    	t.references :company, foreign_key: true

      t.timestamps
    end
  end
end
