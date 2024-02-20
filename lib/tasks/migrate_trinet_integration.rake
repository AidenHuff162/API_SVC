namespace :manage_trinet_integration do

  desc 'Create trinet integration inventory and configurations'
  task trinet: :environment do  
    
    puts 'Creating trinet inventory.'
    attributes = { display_name: 'Trinet', status: 2, category: 1, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018670517-Sapling-Trinet-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'trinet', enable_multiple_instance: true }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created trinet inventory.'

    puts 'Creating trinet inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Company Code', field_type: 'text',
      width: '100', help_text: 'Company Code', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'Client ID', field_type: 'text', width: '100', help_text: 'Client ID', position: 2 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'credentials', field_name: 'Client Secret', field_type: 'text', width: '100', help_text: 'Client Secret', position: 3, is_encrypted: true }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'credentials', field_name: 'Access Token', field_type: 'text', width: '100', help_text: 'Access Token', position: 4, is_encrypted: true, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = {category: 'credentials', field_name: 'Expires In', field_type: 'text', width: '100', help_text: 'Expires In', position: 5, is_encrypted: true, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    puts 'Created trinet inventory configurations.'
    
    puts 'Uploading trinet inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/trinet_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/trinet_dialog_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded trinet inventory logos.'
  end

  
  desc 'Migrate Trinet Credentials'
  task trinet_credentials: :environment do

    puts 'Creating Trinet Instance.'
    Integration.where(api_name: 'trinet').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Company Code'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.company_code, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Client ID'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.client_id, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Client Secret'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.client_secret, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
        
        field_name = 'Access Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.access_token, name: field_name, integration_configuration_id: configuration.id }
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
    puts 'Completed Trinet Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:trinet, :trinet_credentials]
end