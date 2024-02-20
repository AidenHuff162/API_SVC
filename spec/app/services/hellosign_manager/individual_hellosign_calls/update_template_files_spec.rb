require 'rails_helper'

RSpec.describe HellosignManager::IndividualHellosignCalls::UpdateTemplateFiles do
  let(:company){(create(:company))}
  let(:user) {(create(:user, company: company))}
  let(:paperwork_template) {(create(:paperwork_template, company: company))}
  let(:hellosign_call) {(create(:update_template_files, company: company, job_requester: user, user_ids: user.id, paperwork_template_ids: [paperwork_template.id]))}
  let(:hellosign_call_2) {(create(:update_template_files, company: company, job_requester: user, user_ids: user.id))}

   before(:all) do
    WebMock.disable_net_connect!
  end

  before(:each) do
    allow_any_instance_of(PaperworkTemplate).to receive(:create_hellosign_template).and_return(true)
    response = double('data', :data => {'custom_fields' => [], 'signature_request_id' => '1'})
    HelloSign.stub(:update_template_files).and_return(response)
  end

  context "Update Template Files" do
    let(:update_template_files) {HellosignManager::IndividualHellosignCalls::UpdateTemplateFiles.new(hellosign_call, nil)}
    let(:update_template_files_2) {HellosignManager::IndividualHellosignCalls::UpdateTemplateFiles.new(hellosign_call_2, nil)}
    
    it "HelloSignCall state will complete when paperwork_template is not blank" do
      expect{update_template_files.call}.to change(hellosign_call, :state).from('in_progress').to('completed')
    end
    
    it "HelloSignCall state will fail when paperwork_template is blank" do
      expect{update_template_files_2.call}.to change(hellosign_call_2, :state).from('in_progress').to('failed')
    end
  end
end