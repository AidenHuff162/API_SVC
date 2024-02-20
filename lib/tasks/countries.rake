namespace :countries do

  desc "Add missing countries to countries table"
  task add: :environment do
    CS.countries.each do |country_key, country_value|
      unless Country.find_by("LOWER(key) = ?", country_key.downcase)
        country = Country.create(key: country_key, name: country_value, city_type: "City")
        CS.states(country_key).each do |state_key, state_value|
          country.states.create(key: state_key, name: state_value)
        end
      end
      puts "#{country_value} is added along it's states."
    end
  end

  desc "Update requested countries"
  task update: :environment do
    country = Country.find_by(key: "GS")
    country.destroy unless country.nil?
    country = Country.find_by(key: "JO")
    country.update(name: "Jordan") unless country.nil?
    country = Country.find_by(key: "RU")
    country.update(name: "Russia") unless country.nil?
  end

end
