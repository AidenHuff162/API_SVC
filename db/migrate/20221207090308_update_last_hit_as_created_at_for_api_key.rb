class UpdateLastHitAsCreatedAtForApiKey < ActiveRecord::Migration[6.0]
  def change
  	ApiKey.update_all('last_hit = created_at')
  end
end
