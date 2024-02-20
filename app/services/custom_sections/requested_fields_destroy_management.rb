class CustomSections::RequestedFieldsDestroyManagement

  def destroy_requested_fields_on_profile_template_update(cf_ids, pf_ids, company_id)
    company = Company.find_by(id: company_id)
    return unless company.present?
    begin
      pf_api_ids = []
      if pf_ids.length > 0
        pf_api_ids = company.prefrences['default_fields'].map { |field| field['api_field_id'] if pf_ids.include?(field['id']) }.reject(&:nil?)
      end
      CustomSectionApproval.destroy_requested_fields(cf_ids, 'false', nil, company, nil) if cf_ids.length > 0
      CustomSectionApproval.destroy_requested_fields(pf_api_ids, 'true', nil, company, nil) if pf_api_ids.length > 0
    rescue Exception => e
      create_general_logging(company, 'Destroy Requested Field Service', {cf_ids: cf_ids, pf_api_ids: pf_api_ids, error: e.message})
    end
  end

  def create_general_logging(company, action, data, type='Overall')
    general_logging = LoggingService::GeneralLogging.new
    general_logging.create(company, action, data, type)
  end

end
