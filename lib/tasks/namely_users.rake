namespace :namely_users do

  desc 'Removing inactive users'
  task :remove_inactive_users, [:company_id] => :environment do |t, args|
    company = Company.find(args.company_id) rescue nil
    if company.present?
      namely_credentials = company.integrations.find_by(api_name: 'namely') rescue nil
      if namely_credentials.present? && namely_credentials.subdomain.present? && namely_credentials.secret_token.present?
        puts "Removing Inactive Users"
        profiles = HTTParty.get("https://#{namely_credentials.subdomain}.namely.com/api/v1/profiles?limit=5000",
          headers: { accept: "application/json", authorization: "Bearer #{namely_credentials.secret_token}" }
        )

        profiles = JSON.parse(profiles.body)
        profiles['profiles'].try(:each) do |profile|
          user_status = profile['user_status'] rescue nil
          if user_status.present? && user_status.eql?('inactive')
            user = company.users.find_by(namely_id: profile['id']) rescue nil
            puts "User: #{user.inspect}"
            user.destroy! if user.present?
          end
        end
        puts "Removed Inactive Users"
      end
    end
  end

  task :change_users_create_by_source_from_sapling_to_namely, [:company_id] => :environment do |t, args|
    company = Company.find(args.company_id) rescue nil
    if company.present?
      puts "Changing Users Created by Source from Sapling to Namely"
      user_ids = company.users.where(created_by_source: 0).where.not(namely_id: nil).pluck(:id) rescue nil
      puts "----------------------- ID's-----------------------------"
      puts "ID's: #{user_ids.inspect}"

      users = company.users.where.not(namely_id: nil)
      users.try(:each) do |user|
        user.created_by_source = 'namely'
        user.save!
      end
      puts "Changed Users Created by Source from Sapling to Namely"
    end
  end

end
