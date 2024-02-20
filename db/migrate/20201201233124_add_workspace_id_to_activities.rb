class AddWorkspaceIdToActivities < ActiveRecord::Migration[5.1]
  def change
    add_column :activities, :workspace_id, :integer
  end
end
