namespace :create_default_custom_alerts do

  task create_default_custom_alerts: :environment do
    service = CustomEmailAlertService.new
    Company.find_each do |company|
      service.create_default_custom_alerts(company)
    end
  end

end
