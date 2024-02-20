namespace :generate_users_guid do

  task generate_guid: :environment do
    User.with_deleted.find_each do |user|
      puts "User: #{user.email || user.personal_email} | Company: #{user.company.name}"
      temp_guid = nil
      loop do
        temp_guid = "#{user.id}#{SecureRandom.uuid}"
        break temp_guid unless User.with_deleted.where(company_id: user.company_id, guid: temp_guid).exists?
      end
      puts "GUID: #{temp_guid}"
      puts "========================"
      user.update_column(:guid, temp_guid) if temp_guid.present?
    end
  end
end
