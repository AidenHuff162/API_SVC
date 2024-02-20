namespace :manage_fountain_integration do

  desc 'Create Fountain integration inventory and configurations'
  task fountain_inventory: :environment do  
    
    puts 'Creating Fountain inventory.'
    attributes = { position: 1, display_name: 'Fountain', status: 2, category: 0, knowledge_base_url: 'https://help.saplingapp.io/en/articles/5811711',
      data_direction: 1, enable_filters: false, api_identifier: 'fountain', enable_multiple_instance: true }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Fountain inventory.'

    puts 'Creating Fountain inventory configurations.'
    
    attributes = { category: 'credentials', field_name: 'Client ID', field_type: 'client_id', width: '100', help_text: 'Client ID', position: 2, is_encrypted: true}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'credentials', field_name: 'API Key', field_type: 'public_api_key', width: '100', help_text: 'API Key', position: 1, is_encrypted: true}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    puts 'Created Fountain inventory configurations.'
    
    puts 'Uploading Fountain inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/fountain-logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/fountain-logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Fountain inventory logos.'
  end

  desc 'Execute all inventories tasks'
  task all: [:fountain_inventory]
end
