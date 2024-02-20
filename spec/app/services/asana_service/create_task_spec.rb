require 'rails_helper'

RSpec.describe AsanaService::CreateTask do
  let!(:company) { create(:company, subdomain: 'rocketship') }
  let!(:nick) { create(:nick, company: company, start_date: Date.new(2001,2,3)) }
  let!(:workstream) { create(:workstream, company: company) }
  let!(:task) { create(:task, workstream: workstream) }
  let!(:tuc) { create(:task_user_connection, task: task, state: "in_progress", user: nick, owner: nick, send_to_asana: true) }
  let!(:integration) { create(:asana_instance, company: company) }

  before(:each) do
    headers = {
      'Accept'=>'application/json',
      'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Asana-Enable'=>'new_rich_text',
      'Authorization'=>'Bearer xyz',
      'Content-Type'=>'application/json',
      'Host'=>'app.asana.com',
      'User-Agent'=>'Ruby'
    }
    WebMock.disable_net_connect!
    stub_request(:get, "https://app.asana.com/api/1.0/workspaces/xyz").
      with(headers: headers).
      to_return(status: 200, body: %Q({ "data": { "is_organization": "true" } }), headers: {})
    stub_request(:get, "https://app.asana.com/api/1.0/organizations/xyz/teams?limit=100").
      with(headers: headers).
      to_return(status: 200, body: %Q({ "data": [{ "name": "team", "gid": "1" }] }), headers: {})
    stub_request(:get, "https://app.asana.com/api/1.0/teams/1/projects").
      with(headers: headers).
      to_return(status: 200, body: %Q({ "data": [{ "name": "projects", "gid": "1" }] }), headers: {})
    stub_request(:get, "https://app.asana.com/api/1.0/users/nick@test.com").
      with(headers: headers).
      to_return(status: 200, body: %Q({ "data": { "gid": "1" } }), headers: {})
      stub_request(:get, "https://app.asana.com/api/1.0/users/1").
        with(headers: headers).
        to_return(status: 200, body: %Q({ "data": { "gid": "1" } }), headers: {})
    stub_request(:post, "https://app.asana.com/api/1.0/workspaces/xyz/projects").
      with(headers: headers, body: "{\"data\":{\"name\":\"Nick Newton, 02/03/2001\",\"team\":\"1\"}}").
      to_return(status: 200, body: %Q({ "data": { "gid": "1"} }), headers: {})
    stub_request(:post, "https://app.asana.com/api/1.0/tasks").
      with(headers: headers).
      to_return(status: 200, body: %Q({ "data": { "gid": "1"} }), headers: {})
    stub_request(:post, "https://app.asana.com/api/1.0/webhooks").
      with(headers: headers).
      to_return(status: 200, body: %Q({ "data": { "gid": "1"} }), headers: {})
    stub_request(:get, "https://app.asana.com/api/1.0/teams/1/projects?limit=100").
     with(headers: headers).
     to_return(status: 200, body: %Q({ "data": [{ "name": "1"}] }), headers: {})
  end

  it "saves the task receiver's asana id" do
    AsanaService::CreateTask.new(nick).perform
    nick.reload
    expect(nick.asana_id).not_to eq(nil)
  end

  it "saves the created task's asana ID and sets send_to_asana flag to nil" do
    AsanaService::CreateTask.new(nick).perform
    tuc.reload
    expect(tuc.asana_id).not_to eq(nil)
    expect(tuc.send_to_asana).to eq(nil)
  end

end
