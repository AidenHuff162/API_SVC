require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::FifteenFive::UpdateSaplingUsersFromFifteenFive, type: :job do

  it 'should enque UpdateSaplingUsersFromFifteenFive job in sidekiq' do
    FactoryGirl.create(:fifteen_five_integration)
  	fifteen_five_users_job_size = Sidekiq::Queues["receive_employee_from_pm"].size
  	PeriodicJobs::Integrations::FifteenFive::UpdateSaplingUsersFromFifteenFive.new.perform

    expect(Sidekiq::Queues["receive_employee_from_pm"].size).to eq(fifteen_five_users_job_size + 1)
  end
end