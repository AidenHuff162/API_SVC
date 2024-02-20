module Friendlyable
  extend ActiveSupport::Concern

  def set_hash_id
    hash_id = "#{SecureRandom.urlsafe_base64(9).gsub(/-|_/,('a'..'z').to_a[rand(26)])}#{Time.now.to_i}"
    self.update_column(:hash_id, hash_id)
  end

end
