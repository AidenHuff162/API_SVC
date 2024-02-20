namespace :manage_lattice_integration do
  
  desc 'Create lattice integration inventory and configurations'
  task lattice: :environment do  
  
    puts 'Creating Lattice inventory.'
    attributes = { display_name: 'Lattice', status: 2, category: 6, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360019611498-Sapling-Lattice-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'lattice' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Lattice inventory.'

    puts 'Creating Lattice inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Subdomain', field_type: 'subdomain', vendor_domain: '.latticehq.com',
      width: '100', help_text: 'Subdomain', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'API Key', field_type: 'text', width: '100', help_text: 'API Key', position: 2 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)


    puts 'Created Lattice inventory configurations.'

    puts 'Uploading Lattice inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/lattice-full.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 

    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/lattice-thumbnail.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Lattice inventory logos.'
  end
end