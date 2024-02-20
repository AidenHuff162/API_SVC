namespace :manage_pm_integration do
  task fifteen_five: :environment do  

    puts 'Creating 15Five inventory.'
    attributes = { display_name: '15Five', status: 2, category: 6, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360019615618-Sapling-15Five-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'fifteen_five' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created 15Five inventory.'

    puts 'Creating 15Five inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Subdomain', field_type: 'subdomain', vendor_domain: '.15five.com',
      width: '100', help_text: 'Company URL', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Access Token', field_type: 'text', width: '100', help_text: 'Access Token', position: 2 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'settings', toggle_context: 'When a team member is deleted in Sapling, delete their 15Five account', toggle_identifier: 'can delete profile', position: 3 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    puts 'Created 15Five inventory configurations.'

    puts 'Uploading 15Five inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/fifteen-five-logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 

    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/fifteen-five-dialog-logo.png"
    UploadedFile.create!(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded 15Five inventory logos.'
  end
  
  desc 'Migrate 15Five Credentials'
  task fifteen_five_credentials: :environment do

    puts 'Creating 15Five Instance.'
    Integration.where(api_name: 'fifteen_five').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      if instance.present?
        subdomain = 'Subdomain'
        configuration = integration_inventory.integration_configurations.find_by(field_name: subdomain)
        attributes = { value: integration.subdomain, name: subdomain, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        access_token = 'Access Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.access_token, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
        can_delete_profile = 'can delete profile'
        configuration = integration_inventory.integration_configurations.find_by(toggle_identifier: can_delete_profile)
        attributes = { value: integration.can_delete_profile, name: can_delete_profile, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed 15Five Instance creation.'
  end


  task peakon: :environment do  
    
    puts 'Creating Peakon inventory.'
    attributes = { display_name: 'Peakon', status: 2, category: 6, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360019615698-Sapling-Peakon-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'peakon' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    
    puts 'Created Peakon inventory.'
    attributes = { category: 'credentials', field_name: 'Access Token', field_type: 'text', width: '100', help_text: 'Access Token', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'settings', toggle_context: 'When a team member is deleted in Sapling, delete their Peakon account', toggle_identifier: 'can delete profile', position: 3 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    puts 'Created Peakon inventory configurations.'
    
    puts 'Uploading Peakon inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/peakon-logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/peakon-dialog-logo.png"
    UploadedFile.create!(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Peakon inventory logos.'
  end

  desc 'Migrate Peakon Credentials'
  task peakon_credentials: :environment do

    puts 'Creating Peakon Instance.'
    Integration.where(api_name: 'peakon').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      if instance.present?
        access_token = 'Access Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: access_token)
        attributes = { value: integration.access_token, name: access_token, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
        can_delete_profile = 'can delete profile'
        configuration = integration_inventory.integration_configurations.find_by(toggle_identifier: can_delete_profile)
        attributes = { value: integration.can_delete_profile, name: can_delete_profile, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Peakon Instance creation.'
  end

  task small_improvements: :environment do  
    
    puts 'Creating Small Improvements inventory.'
    attributes = { display_name: 'Small Improvements', status: 5, state: 1, category: 6, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360019470257-Sapling-Small-Improvements-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'small_improvements' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    
    
    puts 'Uploading Small Improvements inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/si-logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
  end

  desc 'Execute all inventories tasks'
  task all: [:fifteen_five, :fifteen_five_credentials, :peakon, :peakon_credentials, :small_improvements]
end