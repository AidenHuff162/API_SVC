class CreateIntegrationCredentials < ActiveRecord::Migration[5.1]
  def change
    create_table :integration_credentials do |t|
      t.string :encrypted_value
      t.string :encrypted_value_iv
      t.string :name
      t.references :integration_instance, foreign_key: true, index: true
      t.references :integration_configuration, foreign_key: true, index: true
      t.timestamps null: false
    end
  end
end
