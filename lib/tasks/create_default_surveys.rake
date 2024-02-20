namespace :create_default_surveys do

  task create_default_surveys: :environment do
    puts "---- Creating default surveys ----"
    Company.find_each do |company|
      Survey.create_default_surveys(company)
    end
    puts "---- Completed ----"
  end

end
