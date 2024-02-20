namespace :manage_hirebridge_integration do

  desc 'Create hirebridge integration inventory and configurations'
  task hirebridge_inventory: :environment do  
    
    puts 'Creating hirebridge inventory.'
    attributes = { position: 1, display_name: 'Hirebridge', status: 2, category: 0, knowledge_base_url: 'mailto:help@trysapling.com?Subject=Hirebridge%20Integration',
      data_direction: 1, enable_filters: false, api_identifier: 'hire_bridge', enable_multiple_instance: false }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created hirebridge inventory.'

    puts 'Creating hirebridge inventory configurations.'
    
    attributes = { category: 'credentials', field_name: 'API Key', field_type: 'public_api_key', width: '100', help_text: 'API Key', position: 1}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    puts 'Created hirebridge inventory configurations.'
    
    puts 'Uploading hirebridge inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/hirebridge.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/hirebridge.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded hirebridge inventory logos.'
  end

  desc 'Migrate Hirebridge Credentials'
  task hirebridge_credentials: :environment do

    puts 'Creating Hirebridge Instance.'
    Integration.where(api_name: 'hire_bridge').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'API Key'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.client_id, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Hirebridge Instance creation.'
  end


  desc 'Execute all inventories tasks'
  task all: [:hirebridge_inventory, :hirebridge_credentials]
end