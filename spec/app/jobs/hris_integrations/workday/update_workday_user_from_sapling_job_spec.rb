require 'rails_helper'

RSpec.describe HrisIntegrations::Workday::UpdateWorkdayUserFromSaplingJob , type: :job do
  subject(:update_workday_user_from_sapling_job) { HrisIntegrations::Workday::UpdateWorkdayUserFromSaplingJob.new.perform(user, 'field') }

  let(:company) { create(:company, subdomain: 'workday-company') }
  let(:workday_instance) { create(:workday_instance, company: company) }
  let(:user) { create(:user, company: company) }

  before do
    HrisIntegrationsService::Workday::ManageSaplingInWorkday.any_instance.stub(:call) {'Service Executed'}
    workday_instance.reload
  end

  it 'should execute service UpdateWorkdayFromSapling' do
    expect(update_workday_user_from_sapling_job).to eq('Service Executed')
  end

  it 'should not  execute service UpdateWorkdayFromSapling if user is super_user' do
    user.update(super_user: true)
    expect(update_workday_user_from_sapling_job).not_to eq('Service Executed')
  end

end
