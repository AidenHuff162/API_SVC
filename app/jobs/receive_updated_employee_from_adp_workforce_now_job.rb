class ReceiveUpdatedEmployeeFromAdpWorkforceNowJob < ApplicationJob
  queue_as :receive_employee_from_adp

  def perform(company_id, adp_wfn_enviornment = nil)
    company = Company.find_by(id: company_id)
    
    if company.present? && ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| company.integration_types.include?(api_name) }.present? 
      HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling.new(company, adp_wfn_enviornment).update
    end
  end
end
