namespace :manage_bambooHR_integration do

  desc 'Create BambooHR integration inventory and configurations'
  task bamboohr_inventory: :environment do  
    
    puts 'Creating BambooHR inventory.'
    attributes = { position: 1, display_name: 'BambooHR', status: 2, category: 1, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018774277',
      data_direction: 2, enable_filters: true, api_identifier: 'bamboo_hr', enable_multiple_instance: false, enable_test_sync: true}
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created BambooHR inventory.'

    puts 'Creating BambooHR inventory configurations.'
    
   
    attributes = { category: 'credentials', field_name: 'Subdomain', field_type: 'subdomain', vendor_domain: '.bamboohr.com', width: '100', help_text: 'Subdomain', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'Api Key', field_type: 'text', width: '100', help_text: 'API key', position: 2, is_encrypted: true}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'settings', field_name: 'Can Export New Profile', toggle_context:'Create New Hires In BambooHR', toggle_identifier:'Can Export New Profile', width: '100', position: 3}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    puts 'Created BambooHR inventory configurations.'
    
    puts 'Uploading BambooHR inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/bamboohr.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/bamboohr_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded BambooHR inventory logos.'
  end

  desc 'Migrate BambooHR Credentials'
  task bamboohr_credentials: :environment do

    puts 'Creating BambooHR Instance.'
    Integration.where(api_name: 'bamboo_hr').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: {"location_id"=>["all"], "team_id"=>["all"], "employee_type"=>["all"]}, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1', skip_callback: true }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Subdomain'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.subdomain, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
        field_name = 'Api Key'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.api_key, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
        field_name = 'Can Export New Profile'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.enable_create_profile, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed BambooHR Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:bamboohr_inventory, :bamboohr_credentials]
end