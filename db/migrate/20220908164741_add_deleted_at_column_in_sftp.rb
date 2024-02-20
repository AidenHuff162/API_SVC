class AddDeletedAtColumnInSftp < ActiveRecord::Migration[5.1]
  def change
    add_column :sftps, :deleted_at, :datetime
  end
end
