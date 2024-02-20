namespace :users do

  desc "Expire managed_users cache"
  task expire_managed_users_cache: :environment do
    users = User.joins(:user_role).where(user_roles: {role_type: UserRole.role_types[:manager]})
    users.find_each do |user|
      Rails.cache.delete([user.id, 'managed_user_count'])
      Rails.cache.delete([user.id, 'indirect_reports_ids'])
    end
  puts "Expired Cache"
  end
end
