namespace :bamboo_users do

  task :change_users_create_by_source_from_sapling_to_bamboo, [:company_id] => :environment do |t, args|
    company = Company.find(args.company_id) rescue nil
    if company.present?
      puts "Changing Users Created by Source from Sapling to BambooHR"
      users = company.users.where.not(bamboo_id: nil)
      users.try(:each) do |user|
        user.created_by_source = User::created_by_sources[:bamboo]
        user.save!
      end
      puts "Changed Users Created by Source from Sapling to BambooHR"
    end
  end

  task :removes_user_private_information, [:company_id] => :environment do |t, args|
    company = Company.find(args.company_id) rescue nil
    if company.present?
      puts "Removing Users Private Information"
      users = company.users.where.not(bamboo_id: nil)
      update_restricted_field_ids = company.custom_fields.where(name: Integration::UPDATE_RESTRICTED_BAMBOO_FIELDS).pluck(:id) rescue []
      update_restricted_sub_field_ids = company.custom_fields.where('name ILIKE ?', 'Home Address').first.sub_custom_fields.pluck(:id) rescue []
      users.try(:each) do |user|
        user_custom_field = user.custom_field_values.where(custom_field_id: update_restricted_field_ids)
        user_custom_field.destroy_all if user_custom_field.present?
        user_sub_custom_field = user.custom_field_values.where(sub_custom_field_id: update_restricted_sub_field_ids)
        user_sub_custom_field.destroy_all if user_sub_custom_field.present?
      end
      puts "Removed Users Private Information"
    end
  end
end
