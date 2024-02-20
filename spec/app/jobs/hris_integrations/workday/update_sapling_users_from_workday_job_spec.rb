require 'rails_helper'

RSpec.describe HrisIntegrations::Workday::UpdateSaplingUsersFromWorkdayJob , type: :job do
  subject(:update_sapling_users_from_workday_job) { HrisIntegrations::Workday::UpdateSaplingUsersFromWorkdayJob.new }

  let(:company) { create(:company) }

  it 'should execute service fetch_all' do
    result = update_sapling_users_from_workday_job.perform(company.id, true)
    expect(recently_updated_mapper[result]).to eq('Service Fetch Worker Executed')
  end

  it 'should not execute service fetch_all if company not present' do
    result = update_sapling_users_from_workday_job.perform(nil)
    expect(recently_updated_mapper[result]).not_to eq('Service Fetch Worker Executed')
  end

  describe 'When fetch_all is false' do
    it 'should not execute service fetch_all' do
      result = update_sapling_users_from_workday_job.perform(company.id, false)
      expect(recently_updated_mapper[result]).not_to eq('Service Fetch Worker Executed')
    end

    it 'should execute service fetch_recently_updated' do
      result = update_sapling_users_from_workday_job.perform(company.id)
      expect(recently_updated_mapper[result]).to eq('Service Fetch Updated Worker Executed')
    end

    it 'should not execute service fetch_recently_updated if company not present' do
      result = update_sapling_users_from_workday_job.perform(nil)
      expect(recently_updated_mapper[result]).not_to eq('Service Fetch Updated Worker Executed')
    end
  end

  it 'should not execute service fetch_recently_updated if fetch_all is true' do
    result = update_sapling_users_from_workday_job.perform(company.id, true)
    expect(recently_updated_mapper[result]).not_to eq('Service Fetch Updated Worker Executed')
  end

  def recently_updated_mapper
    {
      true => 'Service Fetch Worker Executed',
      false => 'Service Fetch Updated Worker Executed'
    }
  end

end
