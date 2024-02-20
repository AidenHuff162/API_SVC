require 'rails_helper'

RSpec.describe TimeOff::SendRequestOnSlack, type: :job do
  subject(:company) {FactoryGirl.create(:company, time_zone: "Pacific Time (US & Canada)")}
  let!(:slack_integration) {create(:slack_integration, company: company, api_name: "slack_notification")}
  let!(:nick) {FactoryGirl.create(:user_with_manager_and_policy, company: company, start_date: Date.today - 1.year, slack_notification: true)}
  before do  
    allow_any_instance_of(Slack::Web::Client).to receive(:users_lookupByEmail) { JSON.parse({"ok": true, "user": {"id": "id"}}.to_json)}
    allow_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage) { true }
    User.current = nick
  end

  describe 'Send Overdue requests email' do
    let!(:request) {create(:default_pto_request,  user: nick, pto_policy_id: nick.assigned_pto_policies.first.pto_policy_id)}
    
    it 'should send request to slack' do
      res = TimeOff::SendRequestOnSlack.new.perform(request.id, nick.id)
      expect(res).to eq(true)
    end

    it 'should not send request to slack if user not present' do
      res = TimeOff::SendRequestOnSlack.new.perform(request.id, nil)
      expect(res).to_not eq(true)
    end
  end
end
