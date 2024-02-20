namespace :manage_jazzhr_integration do

  desc 'Create jazzhr integration inventory and configurations'
  task jazzhr_inventory: :environment do  
    
    puts 'Creating jazzhr inventory.'
    attributes = { position: 0, display_name: 'JazzHR', status: 2, category: 0, knowledge_base_url: 'https://help.saplingapp.io/en/articles/3288438-jazzhr-integration-guide',
      data_direction: 1, enable_filters: false, api_identifier: 'jazz_hr', enable_multiple_instance: false,}
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created jazzhr inventory.'

    puts 'Creating jazzhr inventory configurations.'

    attributes = { category: 'credentials', field_name: 'API Key', field_type: 'text', width: '100', help_text: 'API Key', position: 0, is_encrypted: true}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Client ID', field_type: 'public_api_key', width: '100', help_text: 'Client ID', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'credentials', field_name: 'Client Secret', field_type: 'public_api_key', width: '100', help_text: 'Secret', position: 2}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    puts 'Created jazzhr inventory configurations.'
    
    puts 'Uploading jazzhr inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/jazzhr.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/jazzhr.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded jazzhr inventory logos.'
  end

  desc 'Migrate JazzHR Credentials'
  task jazzhr_credentials: :environment do

    puts 'Creating JazzHR Instance.'
    Integration.where(api_name: 'jazz_hr').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'API Key'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.api_key, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Client ID'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.client_id, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Client Secret'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.client_secret, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed JazzHR Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:jazzhr_inventory, :jazzhr_credentials]
end