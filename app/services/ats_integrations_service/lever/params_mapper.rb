class AtsIntegrationsService::Lever::ParamsMapper
  
  def candidate_data_params_mapper 
    {
      first_name: { attribute: 'name', section: 'candidate_data', secondary_resource: nil, in_array: nil, is_split: true, split_index: 0 },
      last_name: { attribute: 'name', section: 'candidate_data', secondary_resource: nil, in_array: nil, is_split: true, split_index: 1 },
      personal_email: { attribute: 'emails', section: 'candidate_data', secondary_resource: nil, in_array: 0, is_split: false, split_index: nil },
      phone_number: { attribute: 'phones', section: 'candidate_data', secondary_resource: 'value', in_array: 0, is_split: false, split_index: nil },
      start_date: { attribute: 'archived', section: 'candidate_data', secondary_resource: 'archivedAt', in_array: nil, is_split: false, split_index: nil },
      location_id: { attribute: 'location', section: 'candidate_data', secondary_resource: nil, in_array: nil, is_split: false, split_index: nil }
    }
  end

  def hired_candidate_form_fields_params_mapper 
    {
      start_date: { attribute: 'start date', section: 'hired_candidate_form_fields', identifier: 'text', secondary_resource: 'value' },
      location_id: { attribute: 'location', section: 'hired_candidate_form_fields', identifier: 'text', secondary_resource: 'value' }
    }
  end

  def offer_data_params_mapper identifiers
    {
      start_date: { attribute: 'value', section: 'offer_data', identifier: 'anticipated_start_date', field_category: 'default' },
      team_id: { attribute: 'value', section: 'offer_data', identifier: identifiers[:team_identifier], field_category: 'default' },
      base_salary: { attribute: 'value', section: 'offer_data', identifier: 'salary_amount', field_category: 'both' },
      location_id: { attribute: 'value', section: 'offer_data', identifier: 'location|custom_location', field_category: 'default' },
      employee_type: { attribute: 'value', section: 'offer_data', identifier: 'custom_employment_status', field_category: 'default' },
      preferred_name: { attribute: 'value', section: 'offer_data', identifier: 'custom_preferred_name', field_category: 'custom' },
      title: { attribute: 'value', section: 'offer_data', identifier: 'job_title', field_category: 'default' },
      manager_id: { attribute: 'value', section: 'offer_data', identifier: 'hiring_manager', field_category: 'default' }
    }
  end

  def candidate_posting_data_params_mapper identifiers
    {
      title: { attribute: 'text', section: 'candidate_posting_data', secondary_resource: nil },
      team_id: { attribute: 'categories', section: 'candidate_posting_data', secondary_resource: identifiers[:team_identifier] },
      location_id: { attribute: 'categories', section: 'candidate_posting_data', secondary_resource: 'location' },
      employee_type: { attribute: 'categories', section: 'candidate_posting_data', secondary_resource: 'commitment' },
      manager_id: { attribute: 'hiringManager', section: 'candidate_posting_data', secondary_resource: nil }
    }
  end

  def hired_candidate_requisition_data_params_mapper 
    {
      title: { attribute: 'Job Title', is_lever_custom_field: true, is_sapling_custom_field: false, section: 'hired_candidate_requisition_data' },
      location_id: { attribute: 'Location', is_lever_custom_field: true, is_sapling_custom_field: false, section: 'hired_candidate_requisition_data' },
      team_id: { attribute: 'Department', is_lever_custom_field: true, is_sapling_custom_field: false, section: 'hired_candidate_requisition_data' },
      employee_type: { attribute: 'Status', is_lever_custom_field: true, is_sapling_custom_field: 'both', section: 'hired_candidate_requisition_data' },
      manager_id: { attribute: 'Manager', is_lever_custom_field: true, is_sapling_custom_field: false, section: 'hired_candidate_requisition_data' }
    }
  end

  def application_data_params_mapper 
    {
      manager_id: { attribute: 'postingHiringManager', section: 'application' }
    }
  end
end
