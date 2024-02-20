namespace :smart_assignment_configuration do
  
  task create_default_sa_configuration: :environment do

    puts "... Creating default SA configuration settings ..."

    companies = Company.includes(:smart_assignment_configuration)
    companies.find_each do |company|
      default_filters = ["loc", "dpt"]
      employment_status_id = company.custom_fields.where(field_type: 13).take&.id.to_s
      default_filters.push(employment_status_id)

      SmartAssignmentConfiguration.create!(company_id: company.id, meta: {"activity_filters": default_filters, "smart_assignment_filters": default_filters}) unless company.smart_assignment_configuration
    end

    puts "... Completed ..."


  end


end
