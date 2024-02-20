require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::SmartRecruiters::ImportPendingHiresFromSmartRecruiters, type: :job do

	let!(:company) { create(:company) }
	let!(:smart_recruiters_integration) { create(:smartrecruiters_integration, company: company) }

  it 'should enque ImportPendingHiresFromSmartRecruiters job in sidekiq' do
    expect{ PeriodicJobs::Integrations::SmartRecruiters::ImportPendingHiresFromSmartRecruiters.new.perform }.to have_enqueued_job(ImportPendingHiresFromSmartRecruitersJob)
  end
end