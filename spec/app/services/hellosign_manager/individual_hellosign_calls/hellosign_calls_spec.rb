require 'rails_helper'

RSpec.describe HellosignManager::IndividualHellosignCalls::HellosignCalls do

  let(:company) {(create(:company))}
  let(:user) {(create(:user, company: company))}
  let(:paperwork_request) {(create(:paperwork_request, user: user))}
  let(:hellosign_call) {(create(:hellosign_call, company: company, bulk_paperwork_requests: [{paperwork_request_id: paperwork_request.id , user_id: user.id}], job_requester: user, api_end_point: :bulk_send_job_information, hellosign_bulk_request_job_id: 1))}


  before(:each) do
    allow_any_instance_of(PaperworkRequest).to receive(:create_signature_request).and_return(true)
  end

    context "Hellosign Calls" do
    let(:manage_hello_sign_call) {HellosignManager::IndividualHellosignCalls::HellosignCalls.new(hellosign_call, paperwork_request)} 
    
    it "Test will be pass when api_end_point is equals to bulk_send_job_information " do
      expect(manage_hello_sign_call.api_endpoints[:bulk_send_job_information]).to eq('BulkSendJobInformation')
    end

    it "Test will be pass when api_end_point is equals to create_embedded_signature_request_with_template_combined " do
      expect(manage_hello_sign_call.api_endpoints[:create_embedded_signature_request_with_template_combined]).to eq('EmbeddedSignatureRequestWithTemplateCombined')
    end

    it "Test will be pass when api_end_point is equals to create_embedded_signature_request_with_template " do
      expect(manage_hello_sign_call.api_endpoints[:create_embedded_signature_request_with_template]).to eq('EmbeddedSignatureRequestWithTemplate')
    end

    it "Test will be pass when api_end_point is equals to firebase_signed_document " do
      expect(manage_hello_sign_call.api_endpoints[:firebase_signed_document]).to eq('FirebaseSignedDocument')
    end

    it "Test will be pass when api_end_point is equals to signature_request_files " do
      expect(manage_hello_sign_call.api_endpoints[:signature_request_files]).to eq('SignatureRequestFile')
    end

    it "Test will be pass when api_end_point is equals to update_signature_request_cosigner " do
      expect(manage_hello_sign_call.api_endpoints[:update_signature_request_cosigner]).to eq('UpdateSignatureRequestCosigner')
    end

    it "Test will be pass when api_end_point is equals to update_template_files " do
      expect(manage_hello_sign_call.api_endpoints[:update_template_files]).to eq('UpdateTemplateFiles')
    end

    it "HellosignCall will be failed when an exception will raise" do
      WebMock.allow_net_connect!
      hellosign_call.update!(api_end_point: :signature_request_files)
      
      expect{manage_hello_sign_call.call; hellosign_call.reload}.to change(hellosign_call, :state).from('in_progress').to('failed')
      WebMock.disable_net_connect!
    end
  end 
end