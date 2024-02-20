namespace :manage_kallidus_integration do

  desc 'Create Learn integration inventory and configurations'
  task learn: :environment do  
    
    puts 'Creating Learn inventory.'
    attributes = { position: 1, display_name: 'Learn', status: 2, category: 7, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/4405061396497-Sapling-Kallidus-Learn-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'kallidus_learn' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Learn inventory.'

    puts 'Creating Learn inventory configurations.'
    
    if !Rails.env.production?
      attributes = { category: 'credentials', field_name: 'Subdomain', field_type: 'subdomain', vendor_domain: '.azure-api.net', width: '100', help_text: 'Subdomain', position: 1 }
      integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    end
    
    attributes = { category: 'credentials', field_name: 'API key', field_type: 'text', width: '100', help_text: 'API key', position: 2}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'credentials', field_name: 'kallidus_integration_type', field_type: 'text', width: '100', help_text: 'kallidus_integration_type', position: 3}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    puts 'Created Learn inventory configurations.'
    
    puts 'Uploading Learn inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/learn_logo.jpg"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/kallidus_dialog_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Learn inventory logos.'
  end

  desc 'Create Recruit integration inventory and configurations'
  task recurit: :environment do  
    
    puts 'Creating Recruit inventory.'
    attributes = { position: 0, display_name: 'Recruit', status: 2, category: 7, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/4405069673489-Sapling-Kallidus-Recruit-Integration-Guide',
      data_direction: 1, api_identifier: 'kallidus_recurit' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Recruit inventory.'

    puts 'Creating Recruit inventory configurations.'
    
    attributes = { category: 'credentials', field_name: 'API Key', field_type: 'sapling_api_key', width: '100', help_text: 'API Key', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    puts 'Created Recruit inventory configurations.'
    
    puts 'Uploading Recruit inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/kallidus-recruit.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/kallidus_dialog_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Recruit inventory logos.'
  end


  desc 'Execute all inventories tasks'
  task all: [:learn, :recurit]
end