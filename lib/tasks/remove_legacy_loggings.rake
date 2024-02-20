namespace :remove_legacy_loggings do
  desc 'Remove legacy loggings'
  
  task execute: :environment do
    puts "Execution Started!"

    remaining = ApiLogging.count
    ApiLogging.try(:find_each) do |api_logging|
      remaining = remaining - 1
      puts "=> API Loggings Remaining: #{remaining}"
      api_logging.delete
    end

    # remaining = Webhook.count
    # Webhook.try(:find_each) do |webhook|
    #   remaining = remaining - 1
    #   puts "=> WEBHOOK Loggings Remaining: #{remaining}"
    #   webhook.delete
    # end

    remaining = Logging.count
    Logging.try(:find_each) do |logging|
      remaining = remaining - 1
      puts "=> INTEGRATION Loggings Remaining: #{remaining}"
      logging.delete
    end

    puts "Execution Completed!"
    puts "<<<<<<<<<<<<<<<<<<<<<<<<<><>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n"*2
    puts "API Loggings: #{ApiLogging.count}"
    # puts "WEBHOOK Loggings: #{Webhook.count}"
    puts "INTEGRATION Loggings: #{Logging.count}"
    puts "<<<<<<<<<<<<<<<<<<<<<<<<<><>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n"*2
  end
end