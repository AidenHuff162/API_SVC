class AddEnvMigrationInPaperworkTemplate < ActiveRecord::Migration[6.0]
  def change
    add_column :paperwork_templates, :env_migration, :string, default: nil
  end
end
