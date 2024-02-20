require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::Workday::UpdateSaplingUsersFromWorkday, type: :job do

  let(:company) { create(:company, subdomain: 'workday-company') }
  let(:workday_instance) { create(:workday_instance, company: company) }

  it 'should enqueue UpdateSaplingUsersFromWorkday job in sidekiq' do
    workday_instance.reload
    workday_job = PeriodicJobs::Integrations::Workday::UpdateSaplingUsersFromWorkday
    expect { workday_job.perform_async }.to change { Sidekiq::Queues['default'].size }.by(1)
  end
end
