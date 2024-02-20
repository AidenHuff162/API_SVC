class AtsIntegrationsService::Lever::ManageLeverProfileInSapling

  def fetch_lever_sections_data(integration, opportunity_id, api_key, current_company)
    lever_custom_fields = []
    @helper = initialize_helper

    candidate_data = AtsIntegrationsService::Lever::CandidateDataBuilder.new.get_candidate_data(opportunity_id, api_key, current_company)
    return 'failed' unless @helper.valid_candidate_data(candidate_data)
      
    lever_custom_fields.concat(candidate_data[:lever_custom_field]) if candidate_data[:lever_custom_field].present?
  
  
    referral_data = nil
    if candidate_data.present? && candidate_data[:referral_data].present?
      referral_data = AtsIntegrationsService::Lever::ReferralDataBuilder.new.get_referral_data(opportunity_id, api_key, current_company)
      lever_custom_fields.concat(referral_data[:lever_custom_field]) if referral_data.present?
    end
    
    application = AtsIntegrationsService::Lever::ApplicationDataBuilder.new.get_application_data(opportunity_id, api_key, current_company) rescue {}
    
    hired_candidate_profile_form_fields = AtsIntegrationsService::Lever::HiredCandidateFormFieldsDataBuilder.new.get_hired_candidate_form_fields(opportunity_id, api_key, current_company) rescue []

    offer_data = AtsIntegrationsService::Lever::OfferDataBuilder.new.get_offer_data(opportunity_id, api_key, current_company, integration) rescue {}
    lever_custom_fields.concat(offer_data[:lever_custom_field]) if offer_data && offer_data[:lever_custom_field].present?
    
    hired_candidate_posting = {}
    hired_candidate_requisition = {}

    if application.present?
      hired_candidate_posting = AtsIntegrationsService::Lever::CandidatePostingDataBuilder.new.get_candidate_posting_data(opportunity_id, api_key, current_company, application[:posting], integration) if application[:posting].present?
      hired_candidate_requisition = AtsIntegrationsService::Lever::HiredCandidateRequisitionDataBuilder.new.get_hired_candidate_requisition_data(opportunity_id, api_key, current_company, application[:requisition_id]) if application[:requisition_id].present?
      lever_custom_fields.concat(hired_candidate_requisition[:lever_custom_field]) if hired_candidate_requisition && hired_candidate_requisition[:lever_custom_field].present?
    end

    pending_hire = AtsIntegrationsService::Lever::DataBuilder.new.build_data(integration, opportunity_id, api_key, current_company, candidate_data, referral_data, application, hired_candidate_profile_form_fields, offer_data, hired_candidate_posting, hired_candidate_requisition, lever_custom_fields)
    PendingHire.create_by_lever_mapping(pending_hire, current_company)
    return 'succeed'
  end

  def initialize_helper()
    AtsIntegrationsService::Lever::Helper.new()
  end
end
