require 'rails_helper'

RSpec.describe AsanaService::MockCall do
  let(:company) { create(:company, subdomain: 'rocketship') }
  let(:asana) { create(:asana_instance, company: company) }

  before(:each) do
    stub_request(:get, "https://app.asana.com/api/1.0/users?limit=1&workspace=xyz").with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).to_return(status: 200, body: "{\"access_token\": \"stubbed response\"}", headers: {})
    stub_request(:get, "https://app.asana.com/api/1.0/users?limit=1&workspace=bad").with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).to_return(status: 200, body: "{\"errors\": \"invalid credentials\"}", headers: {})
  end

  it "returns true if supplied credentials do not encounter error from asana API" do
    response = AsanaService::MockCall.new(asana.reload).perform
    expect(response).to eq(true)
  end

  it 'returns errors if supplied credentials encounter error from asana API' do
    asana.integration_credentials.by_name('Asana Organization ID').update(value: 'bad')
    response = AsanaService::MockCall.new(asana).perform
    expect(response).not_to eq(true)
  end

end
