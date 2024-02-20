namespace :manage_gusto_integration do

  desc 'Create Gusto integration inventory and configurations'
  task gusto: :environment do  
    
    puts 'Creating Gusto inventory.'
    attributes = { display_name: 'Gusto', status: 2, category: 1, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360019689758-Sapling-Gusto-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'gusto', enable_multiple_instance: true, enable_connect: true }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Gusto inventory.'

    puts 'Creating Gusto inventory configurations.'
    
    attributes = { category: 'credentials', field_name: 'Company Code', field_type: 'options', width: '100', help_text: 'Company Code', position: 1, is_visible: true }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Access Token', field_type: 'text', width: '100', help_text: 'Access Token', position: 2, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'credentials', field_name: 'Refresh Token', field_type: 'text', width: '100', help_text: 'Refresh Token', position: 3, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'credentials', field_name: 'Expires In', field_type: 'text', width: '100', help_text: 'Expires In', position: 4, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
   
    puts 'Created Gusto inventory configurations.'
    
    puts 'Uploading Gusto inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/display_gusto.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/gusto_dialog_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Gusto inventory logos.'
  end

  desc 'Migrate Gusto Credentials'
  task gusto_credentials: :environment do

    puts 'Creating Gusto Instance.'
    Integration.where(api_name: 'gusto').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1', is_authorized: true, synced_at: integration.last_sync }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      
      if instance.present?
        field_name = 'Access Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.access_token, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

        field_name = 'Refresh Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.refresh_token, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

        field_name = 'Expires In'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.expires_in, name: field_name, integration_configuration_id: configuration.id }
        credential = instance.integration_credentials.find_or_initialize_by(integration_configuration_id: configuration.id)
        credential.assign_attributes(attributes)
        credential.save

      end
    end
    puts 'Completed Gusto Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:gusto, :gusto_credentials]
end