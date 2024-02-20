namespace :manage_servicenow_integration do
  desc 'Create ServiceNow integration inventory and configurations'
  task serviceNow: :environment do

    puts 'Creating ServiceNow inventory.'
    attributes = { display_name: 'ServiceNow', status: 2, category: 2, 
                    knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/4570677445137-Sapling-ServiceNow-Integration-Guide',
                    data_direction: 0, enable_filters: true, enable_test_sync: true, api_identifier: 'service_now' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)

    puts 'Creating ServiceNow inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Domain', field_type: 'text',
                    width: '100',is_encrypted: false, help_text: 'Domain', position: 0 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Username', field_type: 'text',
                    width: '100',is_encrypted: false, help_text: 'Username', position: 1 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Password', field_type: 'text',
                    width: '100',is_encrypted: true, help_text: 'Password', position: 2 }
    integration_inventory.integration_configurations.where('trim(field_name) ILIKE ?', attributes[:field_name])
                                                    .first_or_create(attributes)

    puts 'Uploading ServiceNow inventory logos.'
    display_image_url =  Rails.root.join('app/assets/images/integration_logos/service_now_logo.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url),
                        type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url))

    dialog_display_image_url = Rails.root.join('app/assets/images/integration_logos/service_now_logo.png')
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url),
                        type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url))
  end

  desc 'Execute all inventories tasks'
  task all: [:serviceNow]
end
