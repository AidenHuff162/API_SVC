class AtsIntegrationsService::Fountain::ParamsMapper
  def fountain_params_mapper
    {
      first_name: {name: 'applicant_name', is_custom: false, parent_hash_path: '', parent_hash: '', is_split: true, split_index: 0 },
      last_name: {name: 'applicant_name', is_custom: false, parent_hash_path: '', parent_hash: '', is_split: true, split_index: 1 },
      personal_email: {name: 'applicant_email', is_custom: false, parent_hash_path: '', parent_hash: '' },
      fountain_id: {name: 'applicant_id', is_custom: false, parent_hash_path: '', parent_hash: '' },
      title: {name: 'position_title', is_custom: false, parent_hash_path: '', parent_hash: '' },
      start_date: {name: 'start_date', is_custom: false, parent_hash_path: '', parent_hash: '' },
      employee_type: {name: 'full_or_part_time_confirmed', is_custom: false, parent_hash_path: '', parent_hash: '' },
      manager_id: {name: 'manager_name', is_custom: false, parent_hash_path: '', parent_hash: '' },
      location_id: {name: 'location_internal_mapping', is_custom: false, parent_hash_path: '', parent_hash: '' },
      team_id: {name: 'department', is_custom: false, parent_hash_path: '', parent_hash: '' },
      pay_rate: {name: 'opening_pay_rate', is_custom: true, parent_hash_path: '', parent_hash: '' },
      pay_rate_type: {name: 'rate_type', is_custom: true, parent_hash_path: '', parent_hash: '' },
      office_location: {name: 'location', is_custom: true, parent_hash_path: '', parent_hash: '' },
      adp_company_code: {name: 'company_code', is_custom: true, parent_hash_path: '', parent_hash: '' }
    }
  end
end
