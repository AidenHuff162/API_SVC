require 'rails_helper'

RSpec.describe AsanaService::CompleteTask do
  let!(:nick) { create(:user_with_tasks) }
  let!(:integration) { create(:asana_integration, company: nick.company) }

  before(:each) do
    WebMock.disable_net_connect!
    stub_request(:put, "https://app.asana.com/api/1.0/tasks/1").
      with(
        body: "{\"data\":{\"completed\":true}}",
        headers: {
        'Accept'=>'application/json',
        'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization'=>'Bearer xyz',
        'Content-Type'=>'application/json',
        'Host'=>'app.asana.com',
        'User-Agent'=>'Ruby'
        }).
      to_return(status: 200, body: "{\"data\": { \"completed\": \"true\" } }", headers: {})
  end

  it "complete tasks in asana which are completed in sapling" do
    tuc = nick.task_user_connections.last
    tuc.update!(state: "completed")
    updated_tuc = TaskUserConnection.find_by(id: tuc.id)
    expect(updated_tuc.asana_id).to eq(nil)
  end

end
