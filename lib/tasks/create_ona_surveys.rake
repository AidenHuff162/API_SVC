namespace :create_ona_surveys do

  task create_ona_surveys: :environment do
    puts "---- Creating ONA surveys ----"
    Company.find_each do |company|
      Survey.create_ona_survey(company)
    end
    puts "---- Completed ----"
  end

end
