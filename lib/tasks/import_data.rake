namespace :import_data do
  desc 'Import users from csv file users.csv at Rails.root'
  task :users, [:company_id]=> [:environment] do |t, args|
    company_id = args[:company_id]
    company = Company.find(company_id)
    file_name = 'users.csv'
    cf = company.custom_fields.where(name: 'Position ID').take
    team = company.custom_fields.where(name: 'Team').take
    unless team
      team = CustomField.create!(name: "Team", company_id: company.id, field_type: 4, section: 2, collect_from: 0)
    end
    cf = company.custom_fields.create(name: 'Position ID', section: 2, field_type: 0, collect_from: 1) unless cf

    CSV.foreach(file_name, headers: true) do |row|
      entry = row.to_hash
      next if entry['email'].blank?
      department = company.teams.where(name: entry['department']).first_or_create
      location = company.locations.where(name: entry['location']).first_or_create
      email = entry['email'].try(:downcase)
      personal_email = entry['personal_email'].try(:downcase)
      start_date = Date.strptime(entry['start_date'], '%m/%d/%y') rescue Date.yesterday

      email_first, email_last = email.split('@').first, email.split('@').last
      personal_email_first, personal_email_last = personal_email.split('@').first,  personal_email.split('@').last if personal_email

      user = company.users.find_by(email: email)
      user = company.users.create!(
        first_name: entry['first_name'],
        last_name: entry['last_name'],
        title: entry['title'],
        location: location,
        team: department,
        email: "#{email_first}@#{email_last}",
        personal_email: (personal_email_first ? "#{personal_email_first}@#{personal_email_last}" : nil),
        role: :employee,
        password: ENV['USER_PASSWORD'],
        state: :active,
        current_stage: User.current_stages[:registered],
        start_date: start_date
      ) if !user

      if entry['image_url']
        profile_image = user.create_profile_image!
        profile_image.remote_file_url = entry['image_url']
        profile_image.save!
      end

      profile = user.profile
      profile.update(
        facebook: entry['facebook_url'],
        twitter: entry['twitter_url'],
        linkedin: entry['linkedin_url']
      )
      if entry['team']
        team_value = team.custom_field_options.where(option: entry['team']).first_or_create
        team.custom_field_values.create(user: user, custom_field_option_id: team_value.id)
      end
      cf.custom_field_values.create(user: user, value_text: entry['Position ID']) if entry['Position ID'].present?
    end

    CSV.foreach(file_name, headers: true) do |row|
      entry = row.to_hash
      next if entry['email'].blank?
      email = entry['email'].downcase
      user = User.find_by(email: email)

      if user
        user.manager = User.where(email: entry['manager'].downcase).first if entry['manager']
        user.save!
      end
    end
  end
end
