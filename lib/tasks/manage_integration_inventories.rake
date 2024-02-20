namespace :manage_integration_inventories do

  desc 'Create learnupon integration inventory and configurations'
  task learn_upon: :environment do  
    
    puts 'Creating learn upon inventory.'
    attributes = { display_name: 'LearnUpon', status: 2, category: 5, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360019473957-Sapling-LearnUpon-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'learn_upon' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created learn upon inventory.'

    puts 'Creating learn upon inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Subdomain', field_type: 'subdomain', vendor_domain: '.learnupon.com',
      width: '100', help_text: 'Subdomain', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'Username', field_type: 'text', width: '100', help_text: 'Username', position: 2 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = {category: 'credentials', field_name: 'Password', field_type: 'text', width: '100', help_text: 'Password', position: 3 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    puts 'Created learn upon inventory configurations.'
    
    puts 'Uploading learn upon inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/display_learnupon.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/learnupon_dialog_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded learn upon inventory logos.'
  end

  desc 'Create lessonly integration inventory and configurations'
  task lessonly: :environment do

    puts 'Creating lessonly inventory.'
    attributes = { display_name: 'Lessonly', status: 2, category: 5, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360019473937-Sapling-Lessonly-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'lessonly' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created lessonly inventory.'

    puts 'Creating lessonly inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Subdomain', field_type: 'subdomain', vendor_domain: '.lessonly.com',
      width: '100', help_text: 'Subdomain', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    attributes = { category: 'credentials', field_name: 'API key', field_type: 'text', width: '100', help_text: 'API key', position: 2 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    puts 'Created lessonly inventory configurations.'

    puts 'Uploading lessonly inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/display_lessonly.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/lessonly_dialog_logo.jpg"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url))
    puts 'Uploaded lessonly inventory logos.'
  end

  desc 'Migrate Lessonly Credentials'
  task lessonly_credentials: :environment do

    puts 'Creating lessonly Instance.'
    Integration.where(api_name: 'lessonly').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      if instance.present?
        subdomain = 'Subdomain'
        configuration = integration_inventory.integration_configurations.find_by(field_name: subdomain)
        attributes = { value: integration.subdomain, name: subdomain, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        api_key = 'API key'
        configuration = integration_inventory.integration_configurations.find_by(field_name: api_key)
        attributes = { value: integration.api_key, name: api_key, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed Lessonly Instance creation.'
  end

  desc 'Migrate learnupon Credentials'
  task learnupon_credentials: :environment do

    puts 'Creating learnupon Instance.'
    Integration.where(api_name: 'learn_upon').find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1' }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      
      if instance.present?
        subdomain = 'Subdomain'
        configuration = integration_inventory.integration_configurations.find_by(field_name: subdomain)
        attributes = { value: integration.subdomain, name: subdomain, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        username = 'Username'
        configuration = integration_inventory.integration_configurations.find_by(field_name: username)
        attributes = { value: integration.iusername, name: username, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        password = 'Password'
        configuration = integration_inventory.integration_configurations.find_by(field_name: password)
        attributes = { value: integration.ipassword, name: password, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
    puts 'Completed learnupon Instance creation.'
  end

  desc 'Update Learn upon Logo'
  task update_learnupon_logo: :environment do
    integration_inventory = IntegrationInventory.find_by(api_identifier: 'learn_upon')
    if integration_inventory.present?
      integration_inventory.dialog_display_logo&.destroy
      dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/learnupon_dialog_logo.png"
      UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
        type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
      puts 'Uploaded learn upon inventory logos.'
    end
  end

  desc 'Execute all inventories tasks'
  task all: [:learn_upon, :lessonly, :lessonly_credentials, :learnupon_credentials]
end