# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
Rails.configuration.ld_client = LaunchDarkly::LDClient.new(ENV['LAUNCH_DARKLY_KEY'])
company_attributes = FactoryGirl.attributes_for(:rocketship_company)
company = Company.where(name: company_attributes[:name])
  .first_or_create(company_attributes)

[:nick, :tim, :peter, :sarah].each do |key|
  user_attributes = FactoryGirl.attributes_for(key)
  unless User.exists?(email: user_attributes[:email])
    FactoryGirl.create(key, company: company)
  end
end

['Calendar setup', 'Accounts', 'Team Building'].each do |name|
  company.workstreams.where(name: name).first_or_create
end

employees_data = YAML.load_file(Rails.root.join('db/data/employees.yml')).map do |employee|
  employee.tap do |e|
    e['start_date'] = Date.today - 10.days
  end
end

employees_data.map { |d| d['team'] }.uniq.each do |team_name|
  company.teams.where(name: team_name).first_or_create
end

employees_data.map { |d| d['location'] }.uniq.each do |location_name|
  company.locations.where(name: location_name).first_or_create
end

employees_data.each do |employee|
  user = company.users.where(email: employee['email']).first_or_create(
    employee.slice(
      'first_name', 'last_name', 'personal_email', 'email', 'start_date', 'bio', 'title', 'role'
    ).merge(
      password: ENV['USER_PASSWORD'],
      state: 'active',
      current_stage: 11
    )
  )
  user.location ||= Location.where(name: employee['location']).first_or_create
  user.team ||= Team.where(name: employee['team']).first_or_create
  user.save! if user.changed?
  user.onboarding!
end

employees_data.each do |employee|
  company.users.where(email: employee['email']).first_or_create.tap do |user|
    user.manager ||= company.users.where(email: employee['manager_email']).first
    user.save! if user.changed?
    user.onboarding!
  end
end

[
  {
    name: 'Dinner with Tim',
    user: User.find_by(email: 'tim@test.com')
  },
  {
    name: 'Dinner with Sarah',
    user: User.find_by(email: 'sarah@test.com')
  },
  {
    name: 'Lunch with Peter',
    user: User.find_by(email: 'peter@test.com')
  }
].each do |task|
  company.workstreams.find_by(name: 'Calendar setup')
         .tasks.where(name: task[:name], owner: task[:user], task_type: '0', deadline_in: 0).first_or_create
end

[
  {
    name: 'Add to GitHub',
    user: User.find_by(email: 'sarah@test.com')
  },
  {
    name: 'Add to Dribbble',
    user: User.find_by(email: 'sarah@test.com')
  },
  {
    name: 'Add to Pivotal',
    user: User.find_by(email: 'sarah@test.com')
  }
].each do |task|
  company.workstreams.find_by(name: 'Accounts')
         .tasks.where(name: task[:name], owner: task[:user], task_type: '0', deadline_in: 0).first_or_create
end

[
  {
    name: 'New employee party',
    user: User.find_by(email: 'peter@test.com')
  },
  {
    name: 'Lord of the Rings rewatch',
    user: User.find_by(email: 'tim@test.com')
  }
].each do |task|
  company.workstreams.find_by(name: 'Team Building')
         .tasks.where(name: task[:name], owner: task[:user], task_type: '0', deadline_in: 0).first_or_create
end

[
  {
    name: 'Judgement',
    description: 'We expect you to make wise decisions (people, '\
      'technical, business, and creative) despite ambiguity by '\
      'identifying root causes that go beyond treating symptom. '\
      'You think strategically, and separate what can be done '\
      'well now, and what can be improved later.',
    position: 0
  },
  {
    name: 'Communication',
    description: 'You listen well, instead of reacting fast, so '\
      'you can better understand. You are concise and articulate in '\
      'speech and writing, and treat people with respect independent '\
      'of their status or disagreement with you.',
    position: 1
  },
  {
    name: 'Passion',
    description: 'You inspire others with your thirst for excellence '\
      'and care intensely about our customer success. You celebrate '\
      'team wins and recognize everyone’s contribution.',
    position: 2
  },
  {
    name: 'Impact',
    description: 'You accomplish amazing amounts of important work '\
      'and demonstrate consistently strong performance so colleagues '\
      'can rely upon you. You focus on great results rather than on '\
      'process and exhibit a bias to action.',
    position: 3
  },
  {
    name: 'Curiosity',
    description: 'You learn rapidly and eagerly, and seek to understand '\
      'our strategy, market, subscribers, and suppliers. You are broadly '\
      'knowledgeable about business, technology and entertainment and '\
      'contribute effectively outside of your specialty.',
    position: 4
  },
  {
    name: 'Innovation',
    description: 'You’re conceptualize issues to discover practical solutions '\
      'to hard problems. You challenge prevailing assumptions when warranted, '\
      'and suggest better approaches. You create new ideas that prove useful.',
    position: 5
  }
].each do |company_value|
  unless CompanyValue.exists?(name: company_value[:name])
    FactoryGirl.create(:company_value,
      company_value.slice(:name, :description).merge(company: company))
  end
end

[
  {
    happened_at: Date.new(2002, 1, 1),
    name: 'Rocketship founded',
    description: 'Rocketship is founded by Jason Trudor and Harry Thompson.',
    position: 0
  },
  {
    happened_at: Date.new(2004, 1, 1),
    name: 'Growing Team',
    description: 'Rocketship graduates from Jason’s basement and builds '\
      'team to 20 employees in new office.',
    position: 1
  },
  {
    happened_at: Date.new(2005, 1, 1),
    name: 'First launch',
    description: 'Rocketship completed launch of first satellite that is '\
      'launched into orbit and wins.',
    position: 2
  },
  {
    happened_at: Date.new(2010, 1, 1),
    name: 'Breaking Records',
    description: 'Rocketship becomes the only private company ever to '\
      'return a spacecraft from low­ Earth orbit.',
    position: 3
  },
  {
    happened_at: Date.new(2012, 1, 1),
    name: 'ISS attachment',
    description: 'Spacecraft attached to the International Space Station, '\
      'exchanged cargo payloads, and returned safely to Earth.',
    position: 4
  },
  {
    happened_at: Date.new(2014, 1, 1),
    name: 'International Expansion',
    description: 'Rocketship expands internationally to five locations, '\
      'building the team to 100 people.',
    position: 5
  }
].each do |milestone|
  unless Milestone.exists?(name: milestone[:name])
    FactoryGirl.create(:milestone,
      milestone.slice(:happened_at, :name, :description).merge(company: company))
  end
end
AdminUser.create!(email: 'admin@example.com', password: ENV['ADMIN_PASSWORD'], password_confirmation: ENV['ADMIN_PASSWORD'], expiry_date: Date.today + 7)

stage_started = FactoryGirl.create(:webhook, company: company, event: Webhook.events[:stage_started], configurable: {"stages" => [ "all" ]})
new_pending_hire = FactoryGirl.create(:webhook, company: company, event: Webhook.events[:new_pending_hire], filters: nil)
stage_completed = FactoryGirl.create(:webhook, company: company, event: Webhook.events[:stage_completed], configurable: {"stages" => [ "all" ]})

FactoryGirl.create(:webhook_event, company: company, webhook: stage_started)
FactoryGirl.create(:webhook_event, company: company, webhook: stage_completed)
FactoryGirl.create(:webhook_event, company: company, webhook: new_pending_hire)
FactoryGirl.create(:webhook_event, company: company, webhook: new_pending_hire)

access_token = ENV['SEED_NAMELY_ACCESS_TOKEN']
namely = Namely::Connection.new(access_token: access_token, subdomain: "sapling-sandbox")
countries = namely.countries.all.select { |country| ['United States', 'United Kingdom', 'Canada', 'France', 'Australia', 'Argentina', 'Belgium', 'Brazil', 'Chile', 'China', 'Finland', 'Germany', 'Greece', 'Iceland', 'India', 'Indonesia', 'Japan', 'Malaysia', 'Mexico', 'New Zealand', 'Norway', 'Philippines', 'Russian Federation', 'Singapore', 'Spain', 'Sweden', 'Switzerland', 'Thailand'].include? country.name }
countries.try(:each) do |country|
  Country.create_with(key: country.id, name: country.name, subdivision_type: country.subdivision_type).find_or_create_by(name: country.name)
end
Country.create_with(name: 'Other', subdivision_type: 'state').find_or_create_by(name: 'Other')

Country.where.not(name: 'Other').try(:find_each) do |country|
  states = namely.countries.find(country.key).links['subdivisions']
  states.try(:each) do |state|
    country.states.create_with(key: state['id'], name: state['name']).find_or_create_by(name: state['name'])
  end
end



system("rake manage_integration_inventories:all RAILS_ENV=development")
system("rake create_workspace_images:create")
