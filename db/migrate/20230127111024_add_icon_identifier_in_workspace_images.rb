class AddIconIdentifierInWorkspaceImages < ActiveRecord::Migration[6.0]
  def change
    add_column :workspace_images, :icon_identifier, :string
  end
end
