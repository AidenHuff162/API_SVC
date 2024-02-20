require 'rails_helper'

RSpec.describe HellosignManager::IndividualHellosignCalls::UpdateSignatureRequestCosigner do
  let(:company) {(create(:company))}
  let(:user) {(create(:user, company: company))}
  let(:cosigner) {(create(:user, company: company))}
  let(:document) {(create(:document_with_paperwork_template_with_representative_id, company: company))}
  let(:paperwork_request) {(create(:paperwork_request, user: user, document: document, co_signer_id: cosigner.id ))}
  let(:hellosign_call) {(create(:update_signature_request_cosigner, paperwork_request_id: paperwork_request.id, company: company, job_requester: user, user_ids: user.id))}


  before(:all) do
    WebMock.disable_net_connect!
  end

  before(:each) do
    allow_any_instance_of(PaperworkRequest).to receive(:create_signature_request).and_return(true)
  end

  context "Update Signature Request Cosigner" do
    let(:update_signature_request_cosigner) {HellosignManager::IndividualHellosignCalls::UpdateSignatureRequestCosigner.new(hellosign_call, paperwork_request)}
    
    it "HelloSignCall state will fail when paperwork_request or current_cosigner or prev_cosigner or hellosign_signature_id is blank" do
      response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => '1'})
      HelloSign.stub(:update_signature_request).and_return(response)
      expect{update_signature_request_cosigner.call}.to change(hellosign_call, :state).from('in_progress').to('failed')
    end
    
    it "HelloSignCall state will complete when hellosign_signature_id is not blank" do
      response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => '1'})
      HelloSign.stub(:update_signature_request).and_return(response)
      paperwork_request.stub(:get_hellosign_signature_id).and_return(true)
      expect{update_signature_request_cosigner.call}.to change(hellosign_call, :state).from('in_progress').to('completed')
    end
  end
end