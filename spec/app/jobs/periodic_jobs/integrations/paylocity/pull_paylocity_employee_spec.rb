require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::Paylocity::PullPaylocityEmployee, type: :job do

	let!(:company) { create(:with_paylocity_and_paylocity_integration_type) }
	
  it 'should enque PullPaylocityEmployee job in sidekiq' do
    expect{ PeriodicJobs::Integrations::Paylocity::PullPaylocityEmployee.new.perform }.to change(::HrisIntegrations::Paylocity::UpdateSaplingUserFromPaylocityJob.jobs, :size).by(1)
  end
end