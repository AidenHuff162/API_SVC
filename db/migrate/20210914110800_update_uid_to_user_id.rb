class UpdateUidToUserId < ActiveRecord::Migration[5.1]
  def change
    # User.find_each { |user| user.update_column(:uid, user.id) }
  end
end
