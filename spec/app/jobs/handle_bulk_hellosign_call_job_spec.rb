require 'rails_helper'

RSpec.describe HandleBulkHellosignCallJob, type: :job do


  let(:company) { create(:company) }
  let(:manager) {create(:peter, company: company)}
  let(:user) { create(:user, company: company, manager: manager) }
  let(:doc) { create(:document, company: company) }
  let!(:paperwork_template) { create(:paperwork_template, :template_skips_validate, document_id: doc.id, company_id: company.id) } 
  let!(:paperwork_request) { create(:paperwork_request, :request_skips_validate, document: doc, user: user, state: "assigned", hellosign_signature_request_id: 123) }
  
  before { WebMock.disable_net_connect! }

  context 'pick_single_hellosign_call_at_a_time' do
    let!(:data) {double('data', data: JSON.parse({'name': 'Hire Name'}.to_json))}
    let!(:request) { double('request', data: JSON.parse({'custom_fields': []}.to_json) ) }

    before do
      request.data['custom_fields'] = [data]
      HelloSign.stub(:get_template) { request}
      HTTP::Client.any_instance.stub(:get) {{"signature_requests": [{'signatures': [{"signature_request_id": 'id', 'signer_email_address': user.email}]}]}.to_json}
      HelloSign.stub(:embedded_bulk_send_with_template) { double('template', data: JSON.parse({'signature_request_id': 'signature_request_id'}.to_json))}
      HelloSign.stub(:create_embedded_signature_request_with_template) { double('template', data: JSON.parse({'signature_request_id': 'signature_request_id'}.to_json))}
    end

    it 'should complete only one hellosign call' do
      HellosignCall.create_embedded_bulk_send_with_template_of_individual_document(paperwork_template.id, [user.attributes], user.id, company, 3.days.from_now)
      response = HandleBulkHellosignCallJob.new.perform
      expect(HellosignCall.first.try(:state)).to eq('completed')
      expect(HellosignCall.last.try(:state)).to eq('in_progress')
    end
  end

  context 'create bulk hellosign call and execute it' do
    let!(:data) {double('data', data: JSON.parse({'name': 'Hire Name'}.to_json))}
    let!(:request) { double('request', data: JSON.parse({'custom_fields': []}.to_json) )  }
    before do
      request.data['custom_fields'] = [data]
      HelloSign.stub(:get_template) { request}
      HTTP::Client.any_instance.stub(:get) {{"signature_requests": [{'signatures': [{"signature_request_id": 'id', 'signer_email_address': user.email}]}]}.to_json}
      HelloSign.stub(:embedded_bulk_send_with_template) { double('template', data: JSON.parse({'signature_request_id': 'signature_request_id'}.to_json))}
      HelloSign.stub(:create_embedded_signature_request_with_template) { double('template', data: JSON.parse({'signature_request_id': 'signature_request_id'}.to_json))}
    end

    it 'should create bulk hellosign call and should be completed' do
      hellosign_call = HellosignCall.create_embedded_bulk_send_with_template_of_individual_document(paperwork_template.id, [user.attributes], user.id, company, 3.days.from_now)
      response = HandleBulkHellosignCallJob.new.perform
      expect(HellosignCall.first.try(:state)).to eq('completed')
    end

    it 'should create bulk hellosign call and should be failed' do
        HellosignCall.create_embedded_bulk_send_with_template_of_individual_document(paperwork_template.id, [user.attributes], user.id, company, 3.days.from_now)
        HellosignCall.first.update(paperwork_template_ids: [])
        response = HandleBulkHellosignCallJob.new.perform
        expect(HellosignCall.first.try(:state)).to eq('failed')
      end
  end  
end
