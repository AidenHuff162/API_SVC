namespace :populate_address do

  task :country, [:access_token] => :environment do |t, args|
    namely = Namely::Connection.new(access_token: args.access_token, subdomain: "sapling-sandbox")
    countries = namely.countries.all.select { |country| ['United States', 'United Kingdom', 'Canada', 'France', 'Australia', 'Argentina', 'Belgium', 'Brazil', 'Chile', 'China', 'Finland', 'Germany', 'Greece', 'Iceland', 'India', 'Indonesia', 'Japan', 'Malaysia', 'Mexico', 'New Zealand', 'Norway', 'Philippines', 'Russian Federation', 'Singapore', 'Spain', 'Sweden', 'Switzerland', 'Thailand', 'Denmark', 'Hong Kong', 'Netherlands'].include? country.name }

    puts "================================="
    countries.try(:each) do |country|
      puts country
      if country.name == 'Hong Kong'
        subdivision_type = 'District'
      else
        subdivision_type = country.subdivision_type
      end
      Country.create_with(key: country.id, name: country.name, subdivision_type: subdivision_type).find_or_create_by(name: country.name)
    end
    Country.create_with(name: 'Other', subdivision_type: 'state').find_or_create_by(name: 'Other')
    puts "================================="
  end

  task :state, [:access_token] => :environment do |t, args|
    namely = Namely::Connection.new(access_token: args.access_token, subdomain: "sapling-sandbox")

    Country.where.not(name: 'Other').try(:find_each) do |country|
      puts "================================="
      puts country.name
      if country.name != 'Hong Kong'
        states = namely.countries.find(country.key).links['subdivisions']
        states.try(:each) do |state|
          puts state
          country.states.create_with(key: state['id'], name: state['name']).find_or_create_by(name: state['name'])
        end
      else
        if country.name == 'Hong Kong'
          country.states.create_with(key: 'Central and Western', name: 'Central and Western').find_or_create_by(name: 'Central and Western')
          country.states.create_with(key: 'Eastern', name: 'Eastern').find_or_create_by(name: 'Eastern')
          country.states.create_with(key: 'Islands', name: 'Islands').find_or_create_by(name: 'Islands')
          country.states.create_with(key: 'Kowloon City', name: 'Kowloon City').find_or_create_by(name: 'Kowloon City')
          country.states.create_with(key: 'Kwai Tsing', name: 'Kwai Tsing').find_or_create_by(name: 'Kwai Tsing')
          country.states.create_with(key: 'Kwun Tong', name: 'Kwun Tong').find_or_create_by(name: 'Kwun Tong')
          country.states.create_with(key: 'North', name: 'North').find_or_create_by(name: 'North')
          country.states.create_with(key: 'Sai Kung', name: 'Sai Kung').find_or_create_by(name: 'Sai Kung')
          country.states.create_with(key: 'Sha Tin', name: 'Sha Tin').find_or_create_by(name: 'Sha Tin')
          country.states.create_with(key: 'Sham Shui Po', name: 'Sham Shui Po').find_or_create_by(name: 'Sham Shui Po')
          country.states.create_with(key: 'Southern', name: 'Southern').find_or_create_by(name: 'Southern')
          country.states.create_with(key: 'Tai Po', name: 'Tai Po').find_or_create_by(name: 'Tai Po')
          country.states.create_with(key: 'Tsuen Wan', name: 'Tsuen Wan').find_or_create_by(name: 'Tsuen Wan')
          country.states.create_with(key: 'Wan Chai', name: 'Wan Chai').find_or_create_by(name: 'Wan Chai')
          country.states.create_with(key: 'Wong Tai Sin', name: 'Wong Tai Sin').find_or_create_by(name: 'Wong Tai Sin')
          country.states.create_with(key: 'Yau Tsim Mong', name: 'Yau Tsim Mong').find_or_create_by(name: 'Yau Tsim Mong')
          country.states.create_with(key: 'Yuen Long', name: 'Yuen Long').find_or_create_by(name: 'Yuen Long')
        end
      end
      puts "================================="
    end
  end

  task :city => :environment do |t, args|
    State.all.try(:find_each) do |state|
      puts "================================="
      puts "#{state.name}"
      cities = CS.cities(state.key, state.country.key)
      cities.try(:each) do |city|
        puts city
        state.cities.find_or_create_by(name: city)
      end
      puts "================================="
    end
  end

  task :areacode => :environment do |t, args|
    Country.where.not(name: "Other").try(:find_each) do |country|
      puts "================================="
      puts country.name
      # Namely does not contain this data, must be populated manually
      if country.name == 'United Kingdom'
        country.areacode_type = 'Postcode'
        country.save!
      end
      puts "================================="
    end
  end

end
