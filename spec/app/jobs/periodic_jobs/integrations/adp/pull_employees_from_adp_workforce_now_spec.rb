require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::Adp::PullEmployeesFromAdpWorkforceNow, type: :job do
	let!(:company) { create(:with_adp_us_integration) }
    let!(:adp_us) { create(:adp_wfn_us_integration, company: company, filters: {location_id: ['all'], team_id: ['all'], employee_type: ['all'] })}

 	it 'should enque PullEmployeesFromAdpWorkforceNow job in sidekiq' do
 		expect{ PeriodicJobs::Integrations::Adp::PullEmployeesFromAdpWorkforceNow.new.perform }.to have_enqueued_job(ReceiveUpdatedEmployeeFromAdpWorkforceNowJob)
  end
end