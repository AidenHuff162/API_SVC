namespace :export_data do
  task :users, [:company_id]=> :environment do |t, args|
    company = Company.find(args.company_id)
    users = company.users.to_a
    column_names = ['first_name', 'last_name', 'title', 'location', 'team', 'email',
      'personal_email', 'manager', 'linkedin_url', 'twitter_url', 'facebook_url', 'image_url']

    CSV.open('users.csv', 'w') do |csv|
      csv << column_names
      users.each do |user|
        csv << [
          user.first_name,
          user.last_name,
          user.title,
          (user.location_id.present? ? user.location.name : ''),
          (user.team_id.present? ? user.team.name : ''),
          user.email,
          user.personal_email,
          (user.manager_id.present? ? user.manager.email.downcase : ''),
          user.profile.try(:linkedin),
          user.profile.try(:twitter),
          user.profile.try(:facebook),
          user.try(:profile_image).try(:file_url)
        ]
      end
    end
  end
end
