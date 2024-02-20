require 'rails_helper'

RSpec.describe AsanaService::SyncTasks do
  let!(:company) { create(:company, subdomain: 'rocketship') }
  let!(:nick) { create(:nick, company: company) }
  let!(:workstream) { create(:workstream, company: company) }
  let!(:task) { create(:task, workstream: workstream) }
  let!(:integration_instance) { create(:asana_instance, company: company) }
  let!(:tuc) { create(:task_user_connection, task: task, state: 'in_progress', user: nick, owner: nick, asana_id: 1) }

  before(:each) do
    WebMock.disable_net_connect!
    stub_request(:get, 'https://app.asana.com/api/1.0/tasks/1')
      .with(
        headers: {
          'Accept' => 'application/json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization' => 'Bearer xyz',
          'Content-Type' => 'application/json',
          'Host' => 'app.asana.com',
          'User-Agent' => 'Ruby'
        }
      ).to_return(status: 200, body: '{"data": { "completed": "true" } }', headers: {})
  end

  it 'complete tasks in sapling which are completed in asana' do
    AsanaService::SyncTasks.new.perform
    updated_tuc = TaskUserConnection.find_by(id: tuc.id)
    expect(updated_tuc.state).to eq('completed')
    expect(updated_tuc.asana_id).to eq(nil)
    expect(updated_tuc.completed_by_method).to eq('asana')
  end

end
