require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::Peakon::UpdateSaplingUsersFromPeakon, type: :job do

  it 'should enque UpdateSaplingUsersFromPeakon job in sidekiq' do
    FactoryGirl.create(:peakon_integration)
  	update_organization_chart_job_size = Sidekiq::Queues["receive_employee_from_pm"].size
  	PeriodicJobs::Integrations::Peakon::UpdateSaplingUsersFromPeakon.new.perform
    expect(Sidekiq::Queues["receive_employee_from_pm"].size).to eq(update_organization_chart_job_size + 1)
  end
end