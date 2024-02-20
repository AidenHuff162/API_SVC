namespace :manage_paylocity_integration do

  desc 'Create Paylocity integration inventory and configurations'
  task paylocity: :environment do  
    
    puts 'Creating paylocity inventory.'
    attributes = { display_name: 'Paylocity', status: 2, category: 1, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360020673457-Sapling-Paylocity-Integration-Guide',
      data_direction: 0, enable_filters: true, api_identifier: 'paylocity' }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created paylocity inventory.'

    puts 'Creating paylocity inventory configurations.'
    attributes = { category: 'credentials', field_name: 'Company Code', field_type: 'text',
      width: '100', help_text: 'Company Code', position: 1 }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    options = [{label: 'Onboarding Only', value: 'onboarding_only'}, {label: 'Onboarding + Web-Pay', value: 'onboarding_webpay'}, {label: 'Web-Pay Only', value: 'web_pay_only'}, {label: 'Onboarding + Web-Pay (one-way only)', value: 'one_way_onboarding_webpay'}]
    attributes = { category: 'credentials', field_name: 'Integration Type', field_type: 'dropdown', width: '100', help_text: 'Integration Type', position: 2, dropdown_options: options }
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    

    options = []
    ISO3166::Country.find_country_by_any_name("United States").states.collect { |key, value| key }.each do |state|
      options.push({label: state, value: state}) 
    end
    attributes = {category: 'credentials', field_name: 'Sui State', field_type: 'dropdown', width: '100', help_text: 'Sui State', position: 3, dropdown_options: options}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
    
    puts 'Created Paylocity inventory configurations.'
    
    puts 'Uploading Paylocity inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/paylocity_logo.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/paylocity_dialog_logo.jpeg"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Paylocity inventory logos.'
  end

  
  desc 'Migrate Paylocity Credentials'
  task paylocity_credentials: :environment do

    puts 'Creating Paylocity Instance.'
    Integration.where(api_name: 'paylocity').where.not(company_id: nil).find_each do |integration|
      integration_inventory = IntegrationInventory.find_by_api_identifier(integration.api_name)
      attributes = { api_identifier: integration.api_name, filters: integration.meta, state: :active, integration_inventory_id: integration_inventory.id, 
        company_id: integration.company_id, name: 'Instance No.1', skip_callback: true }

      instance = Company.find_by(id: integration.company_id).integration_instances.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
      instance.reload

      if instance.present?
        field_name = 'Company Code'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.api_company_id, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Integration Type'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.company.paylocity_integration_type, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

        field_name = 'Sui State'
        configuration = integration_inventory.integration_configurations.find_by(field_name: field_name)
        attributes = { value: integration.company.paylocity_sui_state, name: field_name, integration_configuration_id: configuration.id }
        instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)

      end
    end
    puts 'Completed Paylocity Instance creation.'
  end

  desc 'Update Paylocity mapping options.'
  task paylocity_mapping_options: :environment do
    puts 'Updating Paylocity mapping options.'
    integration_inventory = IntegrationInventory.find_by(api_identifier: 'paylocity')
    if integration_inventory.present?
      integration_inventory.update_column(:field_mapping_option, 'custom_groups')
      integration_inventory.update_column(:field_mapping_direction, 'sapling_mapping')
      integration_inventory.update_column(:mapping_description, "Map fields of data between Sapling and your Paylocity integration by selecting available fields below. <a target='_blank' href='https://kallidus.zendesk.com/hc/en-us/articles/360020673457-Sapling-Paylocity-Integration-Guide'>Learn more about Sapling’s integration with Paylocity.</a>")
    end
    puts 'Updated Paylocity mapping options.'
  end

  desc 'Create Paylocity Inventory Field Mappings'
  task paylocity_inventory_mappings: :environment do
    puts 'Creating Paylocity inventory mappings.'
    mappings = [{key: 'costCenter1', name: 'Cost Center 1'}, {key: 'costCenter2', name: 'Cost Center 2'}, {key: 'costCenter3', name: 'Cost Center 3'}]
    integration_inventory = IntegrationInventory.find_by_api_identifier('paylocity')
    mappings.each do |map|
      integration_inventory.inventory_field_mappings.where("trim(inventory_field_key) ILIKE ?", map[:key]).first_or_create({inventory_field_key: map[:key], inventory_field_name: map[:name]})
    end if integration_inventory.present?
    puts 'Created Paylocity inventory mappings.'
  end

  desc 'Create Paylocity Integration Field Mappings'
  task paylocity_integration_mappings: :environment do
    puts 'Creating Paylocity Integration mappings.'
    mappings = [{key: 'costCenter1', name: 'Cost Center 1'}, {key: 'costCenter2', name: 'Cost Center 2'}, {key: 'costCenter3', name: 'Cost Center 3'}]
    integration_inventory = IntegrationInventory.find_by_api_identifier('paylocity')
    if integration_inventory.present? && integration_inventory.integration_instances.present?
      integration_inventory.integration_instances.try(:each_with_index) do |instance, index|
        mappings.each do |map|
          instance.integration_field_mappings.where("trim(integration_field_key) ILIKE ?", map[:key]).first_or_create({integration_field_key: map[:key], custom_field_id: nil, preference_field_id: 'null', is_custom: false, company_id: instance.company_id, field_position: (index + 1)})
        end
      end
    end
    puts 'Created Paylocity Integration mappings.'
  end

  desc 'Fetch dropdown options for cost centers'
  task fetch_dropdown_options: :environment do
    puts 'Fetching dropdown options for cost centers.'
    companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'paylocity' AND integration_instances.state = ?", IntegrationInstance.states[:active])
    cost_centers = ['Cost Center 1', 'Cost Center 2', 'Cost Center 3']
    companies.try(:each) do |company|
      cost_centers.each do |const_center|
        HrisIntegrationsService::Paylocity::CostCenters.new(const_center.downcase.delete(' '), company).fetch    
      end
    end
    puts 'Fetched dropdown options for cost centers.'
  end

  desc 'Execute all inventories tasks'
  task all: [:paylocity, :paylocity_credentials, :paylocity_mapping_options, :paylocity_inventory_mappings, :paylocity_integration_mappings]

  desc 'Execute mapping tasks'
  task mappings: [:paylocity_mapping_options, :paylocity_inventory_mappings, :paylocity_integration_mappings, :fetch_dropdown_options]
end