require 'rails_helper'

RSpec.describe HellosignManager::IndividualHellosignCalls::FirebaseSignedDocument do
  let(:company) {(create(:company))}
  let(:user) {(create(:user, company: company))}
  let(:cosigner) {(create(:user, company: company))}
  let(:document) {(create(:document, company: company))}
  let(:paperwork_request) {(create(:paperwork_request, user: user, document: document, state: 'emp_submitted'))}
  let(:hellosign_call) {(create(:firebase_signed_document,paperwork_request_id: paperwork_request.id, company: company, job_requester: user, user_ids: [user.id,cosigner.id]))}

  before(:all) do
    WebMock.disable_net_connect!
  end

  before(:each) do
    allow_any_instance_of(PaperworkRequest).to receive(:create_signature_request).and_return(true)
    allow_any_instance_of(Firebase::Client).to receive(:set).and_return(true)
  end

  context "Firebase Signed Document" do
    let(:firebase_signed_document) {HellosignManager::IndividualHellosignCalls::FirebaseSignedDocument.new(hellosign_call, paperwork_request)}
    
    it "HelloSignCall state will fail when Already updated or document is not completed on Hellosign" do
      response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => '1', 'is_complete' => false})
      HelloSign.stub(:get_signature_request).and_return(response)
      HelloSign.stub(:signature_request_files).and_return(response)
      expect{firebase_signed_document.call}.to change(hellosign_call, :state).from('in_progress').to('failed')
    end
    
    it "HelloSignCall state will complete when Firebase is set" do
      response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => '1', 'is_complete' => true})
      HelloSign.stub(:get_signature_request).and_return(response)
      HelloSign.stub(:signature_request_files).and_return(response)
      expect{firebase_signed_document.call}.to change(hellosign_call, :state).from('in_progress').to('completed')
    end
  end
end