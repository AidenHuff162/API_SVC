class CreateIdsTokens < ActiveRecord::Migration[5.1]
    def change
      create_table :ids_tokens do |t|
        t.integer :user_id, null: false
        t.integer :company_id, null: false
        t.string :encrypted_access_token
        t.string :encrypted_access_token_iv
        t.string :encrypted_old_access_token
        t.string :encrypted_old_access_token_iv
        t.string :encrypted_id_token, null: false
        t.string :encrypted_id_token_iv, null: false
        t.string :encrypted_refresh_token, null: false
        t.string :encrypted_refresh_token_iv, null: false
        t.datetime :access_token_expiry, null: false
        t.datetime :race_time
        t.datetime :deleted_at
  
        t.timestamps
      end
    end
  end
  