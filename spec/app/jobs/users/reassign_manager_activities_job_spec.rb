require 'rails_helper'

RSpec.describe Users::ReassignManagerActivitiesJob, type: :job do
  let!(:manager) { create(:user, company: company, role: User.roles[:employee])}
  let!(:company) { create(:company, enabled_time_off: true) }
  let!(:user) { create(:user_with_manager_and_policy, state: :active, current_stage: :registered, company: company, manager:manager) }
	before do 
  	allow_any_instance_of(ReassignManagerActivitiesService).to receive(:perform) { 'Service Executed' }
  end
	it 'should run service and return true' do
		res = Users::ReassignManagerActivitiesJob.new.perform(company, user.id, user.manager_id_was)
    expect(res).to eq('Service Executed')
  end
end
