namespace :manage_linkedin_integration do

  desc 'Create Linkedin integration inventory and configurations'
  task linkedin_inventory: :environment do  
    
    puts 'Creating Linkedin inventory.'
    attributes = { position: 1, display_name: 'Linkedin', status: 2, category: 0, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360018811838',
      data_direction: 1, enable_filters: false, api_identifier: 'linked_in', enable_multiple_instance: false }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Linkedin inventory.'

    puts 'Creating Linkedin inventory configurations.'
    
    attributes = { category: 'credentials', field_name: 'Hiring Context', field_type: 'text', width: '100', position: 2, is_visible: false}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    puts 'Created Linkedin inventory configurations.'
    
    puts 'Uploading Linkedin inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/linked_in_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/linked_in_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Linkedin inventory logos.'
  end

  desc 'Migrate Linkedin Credentials'
  task linkedin_credentials: :environment do

    puts 'Creating Linkedin Instance.'
    Integration.where(api_name: 'linked_in').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Hiring Context'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.hiring_context, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Linkedin Instance creation.'
  end

  desc 'Execute all inventories tasks'
  task all: [:linkedin_inventory, :linkedin_credentials]
end
