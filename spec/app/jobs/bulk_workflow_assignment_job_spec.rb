require 'rails_helper'

RSpec.describe BulkWorkflowAssignmentJob, type: :job do

  let!(:company) { create(:company) }
  let!(:user) { create(:user, company: company) }
  let!(:workstream) { create(:workstream, company: company) }
  let!(:task) { create(:task, workstream: workstream) }
  before do 
    allow_any_instance_of(Interactions::TaskUserConnections::Assign).to receive(:perform) { true}
  end

  it 'should execute CreateTaskOnJiraJob and Interactions::TaskUserConnections::Assign' do
    res = BulkWorkflowAssignmentJob.new.perform(JSON.parse({user_task_list: {"#{user.id}": [{'id': task.id}]}, notify_users: true, jira_enabled: true}.to_json), user)
    expect(res.keys).to eq([user.id.to_s])
  end
end