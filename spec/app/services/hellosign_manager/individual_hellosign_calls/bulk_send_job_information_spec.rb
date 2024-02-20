require 'rails_helper'

RSpec.describe HellosignManager::IndividualHellosignCalls::BulkSendJobInformation do
  let(:company) {(create(:company))}
  let(:user) {(create(:user, company: company))}
  let(:paperwork_request) {(create(:paperwork_request, user: user))}

  let(:hellosign_call_1) {(create(:bulk_send_job_information_hellosign_call, company: company, bulk_paperwork_requests: [{paperwork_request_id: paperwork_request.id , user_id: user.id}], job_requester: user))}

  let(:hellosign_call_2) {(create(:bulk_send_job_information_hellosign_call, company: company, bulk_paperwork_requests: [{paperwork_request_id: :abc , user_id: user.id}], job_requester: user))}

  before(:all) do
    WebMock.disable_net_connect!
  end
  
  before(:each) do
    @body = {signature_requests: [signatures: [signer_email_address: user.email]]}
    allow_any_instance_of(PaperworkRequest).to receive(:create_signature_request).and_return(true)

    key = ActionController::HttpAuthentication::Basic.encode_credentials ENV['HELLOSIGN_API_KEY'], 'x'

    stub_request(:get, "https://api.hellosign.com/v3/bulk_send_job/1?page=1&page_size=100").
        with(
          headers: {
        'Accept'=>'application/json',
        'Authorization'=> key
          }).
        to_return(status: 200, body: @body.to_json, headers: {})
  end

  context "Bulk Send Job Information" do
    let(:bulk_send_job_information_1) {HellosignManager::IndividualHellosignCalls::BulkSendJobInformation.new(hellosign_call_1, nil)} 
    let(:bulk_send_job_information_2) {HellosignManager::IndividualHellosignCalls::BulkSendJobInformation.new(hellosign_call_2, nil)}

    it "State is completed when unassigned paperwork requests is empty" do
      expect{bulk_send_job_information_1.call}.to change(hellosign_call_1, :state).from('in_progress').to('completed')
    end

    it "State is partially completed when unassigned paperwork requests is not empty" do
      expect{bulk_send_job_information_2.call}.to change(hellosign_call_2, :state).from('in_progress').to('partially_completed')
    end
  end 
end


