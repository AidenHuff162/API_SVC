namespace :migrations do

  desc 'Enable LDE filters for BambooHR'
  task enable_lde_filters_bamboohr: :environment do
    puts 'Enabling the LDE filters for BambooHR'
    IntegrationInventory.where(api_identifier: 'bamboo_hr').find_each do |inventory|
      inventory.update_column(:enable_filters, true)
    end
    puts 'Enabled the LDE filters for BambooHR'

    puts 'setting filter values to all'
    IntegrationInstance.where(api_identifier: 'bamboo_hr').find_each do |instance|
      instance.update_column(:filters, {"location_id"=>["all"], "team_id"=>["all"], "employee_type"=>["all"]})
    end
    puts 'set the filter values to all'
  end
end