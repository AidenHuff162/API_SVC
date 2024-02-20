class UpdateEncryptedPasswordNullTrue < ActiveRecord::Migration[5.1]
  def change
  	change_column_null(:sftps, :encrypted_password, true)
  end
end
