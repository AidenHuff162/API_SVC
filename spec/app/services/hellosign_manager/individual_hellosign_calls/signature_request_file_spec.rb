require 'rails_helper'

RSpec.describe HellosignManager::IndividualHellosignCalls::SignatureRequestFile do
  let(:company) {(create(:company))}
  let(:user) {(create(:user, company: company))}
  let(:document) {(create(:document, company: company))}
  let(:paperwork_packet) {(create(:paperwork_packet,user: user, company: company))}
  let(:paperwork_request) {(create(:paperwork_request, user: user, document: document))}
  let(:paperwork_request_2) {(create(:paperwork_request, user: user, document: document, paperwork_packet_id: paperwork_packet.id))}
  let(:hellosign_call) {(create(:signature_request_files, paperwork_request_id: paperwork_request.id, company: company, job_requester: user, user_ids: user.id))}

  before(:all) do
    WebMock.disable_net_connect!
  end

  before(:each) do
    allow_any_instance_of(PaperworkRequest).to receive(:create_signature_request).and_return(true)
    allow_any_instance_of(Firebase::Client).to receive(:set).and_return(true)
    response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => '1'})
    HelloSign.stub(:signature_request_files).and_return(response)
  end

  context "Signature Request File" do
    let(:signature_request_file) {HellosignManager::IndividualHellosignCalls::SignatureRequestFile.new(hellosign_call, paperwork_request)}
    let(:signature_request_file_2) {HellosignManager::IndividualHellosignCalls::SignatureRequestFile.new(hellosign_call, paperwork_request_2)}
    
    it "When paperwork_packet_id is blank" do
      expect{signature_request_file.call}.to change(hellosign_call, :state).from('in_progress').to('completed')
    end

    it "When paperwork_packet_id is not blank" do
      expect{signature_request_file_2.call}.to change(hellosign_call, :state).from('in_progress').to('completed')
    end
  end
end