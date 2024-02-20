class AddEncryptedPasswordIvColumnToSftp < ActiveRecord::Migration[5.1]
  def change
  	add_column :sftps, :encrypted_password_iv, :string
  end
end
