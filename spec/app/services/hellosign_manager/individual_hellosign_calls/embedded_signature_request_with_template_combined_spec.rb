require 'rails_helper'

RSpec.describe HellosignManager::IndividualHellosignCalls::EmbeddedSignatureRequestWithTemplateCombined do
  let(:company) {(create(:company))}
  let(:user) {(create(:user, company: company))}
  let(:user2) {(create(:user, company: company))}
  let(:document) {(create(:document, company: company))}
  let(:paperwork_request) {(create(:paperwork_request, user: user, document: document))}

  let(:paperwork_template_1) {(create(:paperwork_template, hellosign_template_id: "1", company: company ))}
  let(:paperwork_template_2) {(create(:paperwork_template, hellosign_template_id: "1", company: nil ))}

  let(:hellosign_call_1) {(create(:embedded_combined_hellosign_call,paperwork_request_id: paperwork_request.id, company: company, job_requester: user, user_ids: [user.id,user2.id], paperwork_template_ids: [paperwork_template_1.id]))}
  let(:hellosign_call_2) {(create(:embedded_combined_hellosign_call,paperwork_request_id: paperwork_request.id, company: company, job_requester: user, user_ids: [user.id,user2.id], paperwork_template_ids: [paperwork_template_2.id]))}

  before(:all) do
    WebMock.disable_net_connect!
  end

   before(:each) do
    allow_any_instance_of(PaperworkRequest).to receive(:create_signature_request).and_return(true)
    allow_any_instance_of(PaperworkTemplate).to receive(:create_hellosign_template).and_return(true)
   end

  context "Embedded Signature Request Combined" do
    let(:create_embedded_signature_request_with_template_combined_1) {HellosignManager::IndividualHellosignCalls::EmbeddedSignatureRequestWithTemplateCombined.new(hellosign_call_1, paperwork_request)}

    let(:create_embedded_signature_request_with_template_combined_2) {HellosignManager::IndividualHellosignCalls::EmbeddedSignatureRequestWithTemplateCombined.new(hellosign_call_2, paperwork_request)}

    it "HelloSignCall state is in-progress when signature request id is nil" do
      response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => nil})
      HelloSign.stub(:get_template).and_return(response)
      HelloSign.stub(:create_embedded_signature_request_with_template).and_return(response)
      expect{create_embedded_signature_request_with_template_combined_1.call}.to_not change(hellosign_call_1, :state)
    end

    it "HelloSignCall state is completed when signature request id is not blank" do
      response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => 1})
      HelloSign.stub(:get_template).and_return(response)
      HelloSign.stub(:create_embedded_signature_request_with_template).and_return(response)
      expect{create_embedded_signature_request_with_template_combined_1.call}.to change(hellosign_call_1, :state).from('in_progress').to('completed')
    end

    it "HelloSignCall state is failed when paperwork template length is zero" do
      response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => 1})
      HelloSign.stub(:get_template).and_return(response)
      HelloSign.stub(:create_embedded_signature_request_with_template).and_return(response)
      expect{create_embedded_signature_request_with_template_combined_2.call}.to change(hellosign_call_2, :state).from('in_progress').to('failed')
    end
  end
end