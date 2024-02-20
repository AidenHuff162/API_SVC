require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::SendEmployeesToBswift, type: :job do

  let!(:company) { create(:company) }
  let!(:bswift_instance) { create(:bswift_instance, company: company)}
	
  it 'should enque SendEmployeesToBswift job in sidekiq' do
  	update_organization_chart_job_size = Sidekiq::Queues["default"].size
  	PeriodicJobs::Integrations::SendEmployeesToBswift.new.perform
    expect(Sidekiq::Queues["default"].size).to eq(update_organization_chart_job_size + 1)
  end
end