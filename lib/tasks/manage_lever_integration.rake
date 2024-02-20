namespace :manage_lever_integration do

  desc 'Create Lever integration inventory and configurations'
  task lever_inventory: :environment do  
    
    puts 'Creating Lever inventory.'
    attributes = { position: 0, display_name: 'Lever', status: 2, category: 0, knowledge_base_url: 'https://kallidus.zendesk.com/hc/en-us/articles/360019469917-Sapling-Lever-Integration-Guide',
      data_direction: 1, enable_filters: false, api_identifier: 'lever', enable_multiple_instance: true }
    integration_inventory = IntegrationInventory.where(api_identifier: attributes[:api_identifier]).first_or_create(attributes)
    puts 'Created Lever inventory.'

    puts 'Creating Lever inventory configurations.'
    
    attributes = { category: 'credentials', field_name: 'API Key', field_type: 'text', width: '100', help_text: 'API Key', position: 0, is_encrypted: true}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    attributes = { category: 'credentials', field_name: 'Signature Token', field_type: 'text', width: '100', help_text: 'Signature Token', position: 1, is_encrypted: true}
    integration_inventory.integration_configurations.where("trim(field_name) ILIKE ?", attributes[:field_name]).first_or_create(attributes)
   
    puts 'Created Lever inventory configurations.'
    
    puts 'Uploading Lever inventory logos.'
    display_image_url = "#{Rails.root}/app/assets/images/integration_logos/lever.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(display_image_url), 
      type: 'UploadedFile::DisplayLogoImage', original_filename: File.basename(display_image_url)) 
    
    dialog_display_image_url = "#{Rails.root}/app/assets/images/integration_logos/logo-lever-dialog.png"
    UploadedFile.create(entity_id: integration_inventory.id, entity_type: 'IntegrationInventory', file: File.open(dialog_display_image_url), 
      type: 'UploadedFile::DialogDisplayLogoImage', original_filename: File.basename(dialog_display_image_url)) 
    puts 'Uploaded Lever inventory logos.'
  end

  desc 'Update Lever mapping options.'
  task lever_mapping_options: :environment do
    puts 'Updating Lever mapping options.'
    integration_inventory = IntegrationInventory.find_by(api_identifier: 'lever')
    if integration_inventory.present?
      integration_inventory.update_column(:field_mapping_option, 'integration_fields')
      integration_inventory.update_column(:field_mapping_direction, 'integration_mapping')
      integration_inventory.update_column(:mapping_description, "Map fields of data between Sapling and your Lever integration by selecting available fields below. <a target='_blank' href='https://kallidus.zendesk.com/hc/en-us/articles/360019469917-Sapling-Lever-Integration-Guide'>Learn more about Sapling’s integration with Lever.</a>")
    end
    puts 'Updated Lever mapping options.'
  end

  desc 'Create Lever Inventory Field Mappings'
  task lever_inventory_mappings: :environment do
    puts 'Creating Lever inventory mappings.'
    mappings = [
      {key: 'title', name: 'Job Title', mapping_options: [{id: 'job_title_offer_data', name: 'Job Title (Offer Form)', section: 'offer_data'}, {id: 'job_title_candidate_posting_data', name: 'Title (Job Posting)', section: 'candidate_posting_data'}, {id: 'job_title_hired_candidate_requisition_data', name: 'Requisition Name (Requisition)', section: 'hired_candidate_requisition_data'}]},
      {key: 'team_id', name: 'Department', mapping_options: [{id: 'location_candidate_data', name: 'Location (Candidate)', section: 'candidate_data'}, {id: 'location_hired_candidate_form_fields', name: 'Location (Form Fields)', section: 'hired_candidate_form_fields'}, {id: 'location_offer_data', name: 'Location (Offer Form)', section: 'offer_data'}, {id: 'location_candidate_posting_data', name: 'Location (Job Posting)', section: 'candidate_posting_data'}, {id: 'location_hired_candidate_requisition_data', name: 'Location (Requisition)', section: 'hired_candidate_requisition_data'}, {id: 'team_offer_data', name: 'Team (Offer Form)', section: 'offer_data'}, {id: 'team_candidate_posting_data', name: 'Team (Job Posting)', section: 'candidate_posting_data'}, {id: 'department_offer_data', name: 'Department (Offer Form)', section: 'offer_data'}, {id: 'department_candidate_posting_data', name: 'Department (Job Posting)', section: 'candidate_posting_data'}, {id: 'department_hired_candidate_requisition_data', name: 'Team (Requisition)', section: 'hired_candidate_requisition_data'}]}, 
      {key: 'location_id', name: 'Location', mapping_options: [{id: 'location_candidate_data', name: 'Location (Candidate)', section: 'candidate_data'}, {id: 'location_hired_candidate_form_fields', name: 'Location (Form Fields)', section: 'hired_candidate_form_fields'}, {id: 'location_offer_data', name: 'Location (Offer Form)', section: 'offer_data'}, {id: 'location_candidate_posting_data', name: 'Location (Job Posting)', section: 'candidate_posting_data'}, {id: 'location_hired_candidate_requisition_data', name: 'Location (Requisition)', section: 'hired_candidate_requisition_data'}, {id: 'department_offer_data', name: 'Department (Offer Form)', section: 'offer_data'}, {id: 'department_candidate_posting_data', name: 'Department (Job Posting)', section: 'candidate_posting_data'}, {id: 'department_hired_candidate_requisition_data', name: 'Team (Requisition)', section: 'hired_candidate_requisition_data'}]}, 
      {key: 'manager_id', name: 'Manager', mapping_options: [{id: 'manager_application', name: 'Posting Hiring Manager (Application)', section: 'application'}, {id: 'manager_candidate_posting_data', name: 'Hiring Manager (Job Posting)', section: 'candidate_posting_data'}, {id: 'manager_hired_candidate_requisition_data', name: 'Hiring Manager (Requisition)', section: 'hired_candidate_requisition_data'}, {id: 'manager_offer_data', name: 'Hiring Manager (Offer Form)', section: 'offer_data'}]},
      {key: 'start_date', name: 'Start Date', mapping_options: [{id: 'start_date_candidate_data', name: 'Archived At (Candidate)', section: 'candidate_data'}, {id: 'start_date_hired_candidate_form_fields', name: 'Start Date (Form Fields)', section: 'hired_candidate_form_fields'}, {id: 'start_date_offer_data', name: 'Anticipated Start Date (Offer Form)', section: 'offer_data'}]}
    ]
    integration_inventory = IntegrationInventory.find_by_api_identifier('lever')
    mappings.each do |map|
      integration_inventory.inventory_field_mappings.where("trim(inventory_field_key) ILIKE ?", map[:key]).first_or_create({inventory_field_key: map[:key], inventory_field_name: map[:name], integration_mapping_options: map[:mapping_options]})
    end if integration_inventory.present?
    puts 'Created Lever inventory mappings.'
  end

  desc 'Create Lever Integration Field Mappings'
  task lever_integration_mappings: :environment do
    puts 'Creating Lever Integration mappings.'
    mappings = ['title', 'team_id', 'location_id', 'manager_id', 'start_date']
    integration_inventory = IntegrationInventory.find_by_api_identifier('lever')
    if integration_inventory.present? && integration_inventory.integration_instances.present?
      integration_inventory.integration_instances.try(:each) do |instance|
        mappings.each_with_index do |map, index|
          instance.integration_field_mappings.where("trim(integration_field_key) ILIKE ?", map).first_or_create({integration_field_key: map, custom_field_id: nil, preference_field_id: 'null', is_custom: false, company_id: instance.company_id, field_position: (index + 1), integration_selected_option: nil})
        end
      end
    end
    puts 'Created Paylocity Integration mappings.'
  end

  desc 'Execute all inventories tasks'
  task all: [:lever_inventory, :lever_mapping_options, :lever_inventory_mappings, :lever_integration_mappings]

  desc 'Execute mapping tasks'
  task mappings: [:lever_mapping_options, :lever_inventory_mappings, :lever_integration_mappings]
end
