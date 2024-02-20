require 'rails_helper'

RSpec.describe HandleHellosignCallJob, type: :job do


  let(:company) { create(:company) }
  let(:manager) {create(:peter, company: company)}
  let(:user) { create(:user, company: company, manager: manager) }
  let(:doc) { create(:document, company: company) }
  let!(:paperwork_template) { create(:paperwork_template, :template_skips_validate, document_id: doc.id, company_id: company.id) } 
  let!(:paperwork_request) { create(:paperwork_request, :request_skips_validate, document: doc, user: user, state: "assigned", hellosign_signature_request_id: 123) }
  
  before { WebMock.disable_net_connect! }

  context 'create_embedded_signature_request_with_template' do
    let!(:data) {double('data', data: JSON.parse({'name': 'Hire Name'}.to_json))}
    let!(:request) { double('request', data: JSON.parse({'custom_fields': []}.to_json) )  }
    before do
      request.data['custom_fields'] = [data]
      HelloSign.stub(:get_template) { request}
      HelloSign.stub(:create_embedded_signature_request_with_template) { double('template', data: JSON.parse({'signature_request_id': 'signature_request_id'}.to_json))}
    end
    it "should complete hellosign call for individual document" do
      hellosign_call = HellosignCall.create_embedded_signature_request_with_template([user.id], paperwork_request.id, true, company.id, user.id)
      response = HandleHellosignCallJob.new.perform
      expect(hellosign_call.reload.state).to eq('completed')
    end

    it "should delete hellosign_call if request not present" do
      hellosign_call = HellosignCall.create_embedded_signature_request_with_template([user.id], nil, true, company.id, user.id)
      response = HandleHellosignCallJob.new.perform
      expect(hellosign_call.reload.state).to eq('failed')
    end

    it "should complete hellosign call if request not present with smarat assigment" do
      hellosign_call = HellosignCall.create_embedded_signature_request_with_template([user.id], paperwork_request.id, true, company.id, user.id, true)
      response = HandleHellosignCallJob.new.perform
      expect(hellosign_call.reload.state).to eq('completed')
    end
  end

  context 'create_bulk_send_job_information' do
    before do
      HelloSign.stub(:signature_request_files) { 'true'}
      
      stub_request(:get, "https://api.hellosign.com/v3/bulk_send_job/bulk_job_id?page=1&page_size=100").
      with(
        headers: {
        'Accept'=>'application/json',
        'Authorization'=>"Basic #{Base64.strict_encode64(ENV['HELLOSIGN_API_KEY']+":x")}"
        }).to_return(body: {"signature_requests": [{"signature_request_id": 'id', 'signatures': [{'signer_email_address': user.email}]}]}.to_json)
    end

    it "should create_bulk_send_job_information for bulk request" do
      hellosign_call = HellosignCall.create_bulk_send_job_information('bulk_job_id', company.id, [{"paperwork_request_id": paperwork_request.id, "user_id": user.id}], true, user.id)
      response = HandleHellosignCallJob.new.perform
      expect(hellosign_call.reload.state).to eq('completed')
    end

    it "should not create_bulk_send_job_information for for bulk request if request not present" do
      hellosign_call = HellosignCall.create_bulk_send_job_information('bulk_job_id', company.id, [{"paperwork_request_id": nil, "user_id": user.id}], true, user.id)
      response = HandleHellosignCallJob.new.perform
      expect(hellosign_call.reload.state).to eq('partially_completed')
    end
  end

  context 'update_template_files' do
    let!(:data) {double('data', data: JSON.parse({'name': 'Hire Name'}.to_json))}
    let!(:request) { double('request', data: JSON.parse({'custom_fields': []}.to_json) )  }
    before do
      request.data['custom_fields'] = [data]
      HelloSign.stub(:get_template) { request}
      HTTP::Client.any_instance.stub(:get) {{"signature_requests": [{'signatures': [{"signature_request_id": 'id', 'signer_email_address': user.email}]}]}.to_json}
      HelloSign.stub(:embedded_bulk_send_with_template) { double('template', data: JSON.parse({'signature_request_id': 'signature_request_id'}.to_json))}
      HelloSign.stub(:create_embedded_signature_request_with_template) { double('template', data: JSON.parse({'signature_request_id': 'signature_request_id'}.to_json))}
    end

    it "should create_embedded_bulk_send_with_template_of_individual_document for bulk request" do
      paperwork_template.update(is_manager_representative: true)
      hellosign_call = HellosignCall.create_embedded_bulk_send_with_template_of_individual_document(paperwork_template.id, [user], user.id, company, 3.days.from_now)
      response = HandleHellosignCallJob.new.perform
      expect(HellosignCall.where(api_end_point: 'create_embedded_signature_request_with_template').take.try(:state)).to eq('completed')
    end
  end

  context 'update_template_files' do
    before do
      HelloSign.stub(:update_template_files) { double('request', data: {'template_id': 'id'}.stringify_keys)}
    end
    it "should update_template_files for  template" do
      hellosign_call = HellosignCall.update_template_files(paperwork_template.id, company.id, user.id)
      response = HandleHellosignCallJob.new.perform
      expect(HellosignCall.first.reload.state).to eq('completed')
    end
  end
end
