class AddAutoRenewAndLastHitToApiKey < ActiveRecord::Migration[6.0]
  def change
    add_column :api_keys, :auto_renew, :boolean , default: false
    add_column :api_keys, :last_hit, :datetime
  end
end
