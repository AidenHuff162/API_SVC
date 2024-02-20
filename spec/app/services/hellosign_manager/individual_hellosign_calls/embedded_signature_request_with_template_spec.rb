require 'rails_helper'

RSpec.describe HellosignManager::IndividualHellosignCalls::EmbeddedSignatureRequestWithTemplate do
  let(:company) {(create(:company))}
  let(:user) {(create(:user, company: company))}
  let(:user2) {(create(:user, company: company))}
  let(:paperwork_template) {(create(:paperwork_template, hellosign_template_id: "1", company: company))}
  let(:document) {(create(:document_with_paperwork_template, company: company))}
  let(:paperwork_request) {(create(:paperwork_request, user: user, document: document))}
  let(:paperwork_request_2) {(create(:paperwork_request, user: user))}
  let(:hellosign_call) {(create(:embedded_hellosign_call,paperwork_request_id: paperwork_request.id, company: company, job_requester: user, user_ids: [user.id,user2.id], paperwork_template_ids: [paperwork_template.id]))}

  before(:all) do
    WebMock.disable_net_connect!
  end

  before(:each) do
    allow_any_instance_of(PaperworkRequest).to receive(:create_signature_request).and_return(true)
    allow_any_instance_of(PaperworkTemplate).to receive(:create_hellosign_template).and_return(true)
  end

  context "Embedded Signature Request" do
    let(:create_embedded_signature_request_with_template) {HellosignManager::IndividualHellosignCalls::EmbeddedSignatureRequestWithTemplate.new(hellosign_call, paperwork_request)}
    let(:create_embedded_signature_request_with_template_2) {HellosignManager::IndividualHellosignCalls::EmbeddedSignatureRequestWithTemplate.new(hellosign_call, paperwork_request_2)}

    it "HelloSignCall state is in-progress when signature request id is nil" do
      response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => nil})
      HelloSign.stub(:get_template).and_return(response)
      HelloSign.stub(:create_embedded_signature_request_with_template).and_return(response)
      expect{create_embedded_signature_request_with_template.call}.to_not change(hellosign_call, :state)
    end

    it "HelloSignCall state is completed when signature request id is not blank" do
      response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => '1'})
      HelloSign.stub(:get_template).and_return(response)
      HelloSign.stub(:create_embedded_signature_request_with_template).and_return(response)
     expect{create_embedded_signature_request_with_template.call}.to change(hellosign_call, :state).from('in_progress').to('completed')
    end

    it "HelloSignCall state is failed when paperwork template is blank or its state is not saved or document is not present " do
      response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => '1'})
      HelloSign.stub(:get_template).and_return(response)
      HelloSign.stub(:create_embedded_signature_request_with_template).and_return(response)
      expect{create_embedded_signature_request_with_template_2.call}.to change(hellosign_call, :state).from('in_progress').to('failed')
    end
  end
end