class RemoveIdsTable < ActiveRecord::Migration[6.0]
  def change
    drop_table :ids_tokens
  end
end
