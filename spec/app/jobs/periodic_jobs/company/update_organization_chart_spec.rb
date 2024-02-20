# require 'rails_helper'
# RSpec.describe PeriodicJobs::Company::UpdateOrganizationChart, type: :job do
#   it 'should enque UpdateOrganizationChart job in sidekiq' do
#   	update_organization_chart_job_size = Sidekiq::Queues["default"].size
#   	PeriodicJobs::Company::UpdateOrganizationChart.new.perform
#     expect(Sidekiq::Queues["default"].size).to eq(update_organization_chart_job_size + 1)
#   end
# end
