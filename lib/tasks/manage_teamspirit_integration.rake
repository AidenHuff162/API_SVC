namespace :manage_teamspirit_integration do

  desc 'Create teamSpirit integration inventory and configurations'
  task teamSpirit: :environment do

    puts 'Creating Team Spirit inventory.'
    attributes = { display_name: 'TeamSpirit', status: 2, category: 1, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/4413795548305-Sapling-TeamSpirit-Integration-Guide',
      data_direction: 0, enable_filters: true, enable_test_sync: true, api_identifier: 'team_spirit' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Team Spirit inventory.'

    puts 'Creating Team Spirit inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Storage Account Name', field_type: 'text',
      width: '100',is_encrypted: true ,help_text: 'account name', position: 0 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Storage Access Key', field_type: 'text',
      width: '100', is_encrypted: true, help_text: 'access key', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    attributes = { category: 'credentials', field_name: 'Storage Folder Path', field_type: 'text',
      width: '100', help_text: '/sapling/export', position: 2 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    options = [{label: 'Sunday', value: '0'}, {label: 'Monday', value: '1'}, {label: 'Tuesday', value: '2'}, {label: 'Wednesday', value: '3'}, {label: 'Thursday', value: '4'}, {label: 'Friday', value: '5'}, {label: 'Saturday', value: '6'}]
    attributes = { category: 'credentials', field_name: 'Day', field_type: 'dropdown', width: '100', help_text: 'Backup day', position: 4, dropdown_options: options }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)

    puts 'Created Team Spirit inventory configurations.'
    puts 'Uploading teamSpirit inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/team_spirit_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url),
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url))

    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/team_spirit_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url),
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url))
    puts 'Uploaded teamSpirit inventory logos.'
  end

  desc 'Remove teamSpirit container name configurations and credentials'
  task remove_teamSpirit_container: :environment do
    integration_inventory = IntegrationInventory.find_by(api_identifier: 'team_spirit')

    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", 'Storage Container Name')&.take&.destroy
    puts "Storage Container configuration removed"
  end

  desc 'Create teamSpirit folder path configurations'
  task teamSpirit_file_directory: :environment do
    integration_inventory = IntegrationInventory.find_by(api_identifier: 'team_spirit')

    attributes = { category: 'credentials', field_name: 'Storage Folder Path', field_type: 'text',
      width: '100', help_text: '/sapling/export', position: 2, is_required: false }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    puts "Storage folder path added"
  end

  desc 'Execute all inventories tasks'
  task all: [:teamSpirit]

  desc 'Execute configuration changes tasks'
  task configuration_changes: [:remove_teamSpirit_container, :teamSpirit_file_directory]
end
