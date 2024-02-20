class AtsIntegrationsService::Lever::DataBuilder

  delegate :fetch_user_from_lever, to: :helper_service

  def build_data(integration, opportunity_id, api_key, company, candidate_data, referral_data, application, hired_candidate_profile_form_fields, offer_data, hired_candidate_posting, hired_candidate_requisition, lever_custom_fields)
    pending_hire = {}

    pending_hire.merge!(
      first_name: candidate_data.try(:[], :first_name),
      last_name: candidate_data.try(:[], :last_name),
      personal_email: candidate_data.try(:[], :personal_email),
      phone_number: candidate_data.try(:[], :phone_number),
      preferred_name: offer_data.try(:[], :preferred_name),
      base_salary: offer_data.try(:[], :base_salary),
      company_id: company.id,
      lever_custom_fields: lever_custom_fields
    )

    employee_type = offer_data.try(:[], :employee_type)
    employee_type ||= hired_candidate_posting.try(:[], :employee_type)
    employee_type_requisition = hired_candidate_requisition.try(:[], :employee_type)
    if employee_type_requisition.present?
      employee_type = employee_type_requisition
    end

    pending_hire.merge!(employee_type: employee_type)

    mappings = integration.integration_field_mappings
    mappings.each do |mapper|
      if mapper.integration_selected_option.present?
        value = nil

        case mapper.integration_selected_option["section"]
        when 'offer_data'
          value = offer_data.try(:[], "#{mapper.integration_field_key}".to_sym)
        when 'hired_candidate_form_fields'
          value = hired_candidate_profile_form_fields.try(:[], "#{mapper.integration_field_key}".to_sym)
        when 'candidate_posting_data'
          value = hired_candidate_posting.try(:[], "#{mapper.integration_field_key}".to_sym)
        when 'hired_candidate_requisition_data'
          value = hired_candidate_requisition.try(:[], "#{mapper.integration_field_key}".to_sym)
        when 'candidate_data'
          value = candidate_data.try(:[], "#{mapper.integration_field_key}".to_sym)
        when 'application'
          value = application.try(:[], "#{mapper.integration_field_key}".to_sym)
        end

        pending_hire.merge!("#{mapper.integration_field_key}": value)
      end
    end

    pending_hire[:manager_id] = fetch_user_from_lever(opportunity_id, api_key, pending_hire[:manager_id], company, true)
    pending_hire
  end

  def helper_service
    AtsIntegrationsService::Lever::Helper.new
  end
end
