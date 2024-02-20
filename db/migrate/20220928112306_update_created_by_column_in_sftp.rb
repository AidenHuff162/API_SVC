class UpdateCreatedByColumnInSftp < ActiveRecord::Migration[5.1]
  def change
  	change_table :sftps do |t|
  	  t.rename :created_by_id, :updated_by_id
  	end
  end
end
