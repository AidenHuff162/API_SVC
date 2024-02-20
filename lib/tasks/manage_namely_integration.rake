namespace :manage_namely_integration do

  desc 'Create Namely integration inventory and configurations'
  task namely_inventory: :environment do  
    
    puts 'Creating Namely inventory.'
    attributes = { position: 1, display_name: 'Namely', status: 2, category: 1, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018774117-Sapling-Namely-Integration-Guide',
      data_direction: 2, enable_filters: true, api_identifier: 'namely', enable_multiple_instance: false }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Namely inventory.'

    puts 'Creating Namely inventory configurations.'
    
   
    attributes = { category: 'credentials', field_name: 'Company URL', field_type: 'subdomain', vendor_domain: '.namely.com', width: '100', help_text: 'Subdomain', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'Permanent Access Token', field_type: 'text', width: '100', help_text: 'API key', position: 2}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'settings', field_name: 'Can Export New Profile', toggle_context:'Create New Hires In Namely', toggle_identifier:'Can Export New Profile', width: '100', help_text: 'Create New Hires In Namely', position: 3}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    puts 'Created Namely inventory configurations.'
    
    puts 'Uploading Namely inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/namely_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/namely_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Namely inventory logos.'
  end

  desc 'Migrate Namely Credentials'
  task namely_credentials: :environment do

    puts 'Creating Namely Instance.'
    Integration.where(api_name: 'namely').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: {"location_id"=>["all"], "team_id"=>["all"], "employee_type"=>["all"]}, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1', skip_callback: true }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Company URL'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.subdomain, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
        field_name = 'Permanent Access Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.secret_token, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
        field_name = 'Can Export New Profile'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.enable_create_profile, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Namely Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:namely_inventory, :namely_credentials]
end