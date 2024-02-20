namespace :users do

  desc "Update managers in onelogin"
  task update_managers_in_one_login: :environment do
    users = User.where.not(one_login_id: nil, manager_id: nil)
    users.find_each do |user|
      ::SsoIntegrations::OneLogin::UpdateOneLoginUserFromSaplingJob.perform_later(user.id, 'manager_id') if user.manager.present? && user.manager.one_login_id.present?
    end
  puts "Managers updated"
  end
end
