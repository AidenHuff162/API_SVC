namespace :manage_workable_integration do

  desc 'Create workable integration inventory and configurations'
  task workable_inventory: :environment do  
    
    puts 'Creating workable inventory.'
    attributes = { position: 0, display_name: 'Workable', status: 2, category: 0, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360019469877',
      data_direction: 1, enable_filters: false, api_identifier: 'workable', enable_multiple_instance: false}
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created workable inventory.'

    puts 'Creating Workable inventory configurations.'
    
    attributes = { category: 'credentials', field_name: 'Subdomain', field_type: 'subdomain', vendor_domain: '.workable.com', width: '100', help_text: 'Company URL', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Access Token', field_type: 'text', width: '100', help_text: 'Access Token', position: 2, is_encrypted: true }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Subscription Id', field_type: 'text', width: '100', position: 3, is_visible: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    puts 'Created Workable inventory configurations.'
    
    puts 'Uploading Workable inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/workable.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/workable.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Workable inventory logos.'
  end

  desc 'Migrate Workable Credentials'
  task workable_credentials: :environment do

    puts 'Creating Workable Instance.'
    Integration.where(api_name: 'workable').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Subdomain'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.subdomain, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Access Token'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.access_token, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Subscription Id'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.subscription_id, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Workable Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:workable_inventory, :workable_credentials]

end