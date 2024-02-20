class CreateSftps < ActiveRecord::Migration[5.1]
  def change
    create_table :sftps do |t|
      t.string :name, null: false
      t.string :host_url, null: false
      t.integer :authentication_key_type , default: 0, null: false
      t.string :user_name,null: false
      t.string :encrypted_password , null: false
      t.integer :port, null: false
      t.string :folder_path, null: false
      t.references :created_by, foreign_key: { to_table: 'users' }, index:  true
      t.references :company, foreign_key: true
      t.timestamps
    end
  end
end
