require 'rails_helper'

RSpec.describe HrisIntegrations::Bamboo::UpdateBambooDocumentsFromSaplingJob , type: :job do
  let(:company) { create(:company, subdomain: 'rocketship') }
  let(:user) {FactoryGirl.create(:user, company: company, bamboo_id: 'sas')}
  let(:document) { create(:document_with_drafted_paperwork_template, title: 'title', company_id: company.id) }
  let(:request2) { create(:paperwork_request, :request_skips_validate, document_id: document.id, user_id: user.id, state: 'assigned', signed_document: true) }
  let(:document_connection_relation) { create(:document_connection_relation) }
  let!(:document_connection) {create(:user_document_connection, user: user, state: 'completed', document_connection_relation: document_connection_relation)}
  let!(:document_upload_request_file) { create(:document_upload_request_file, entity_id: document_connection.id, entity_type: 'UserDocumentConnection')}
  
  before { allow_any_instance_of(HrisIntegrationsService::Bamboo::File).to receive(:upload) {'Service Executed'}  }

  it 'should execute service UpdateBambooDocumentsFromSaplingJob for paperwork_request' do
    HrisIntegrations::Bamboo::UpdateBambooDocumentsFromSaplingJob.new.perform(request2, user)
    result = request2.uploaded_to_bamboo
    expect(result).to eq(true)
  end

  it 'should not execute service UpdateBambooDocumentsFromSaplingJob for paperwork_request if user bamboo_id not present' do
    user.update(bamboo_id: nil)
    HrisIntegrations::Bamboo::UpdateBambooDocumentsFromSaplingJob.new.perform(request2, user)
    result = request2.uploaded_to_bamboo
    expect(result).to eq(false)
  end

  it 'should execute service UpdateBambooDocumentsFromSaplingJob for document_upload_request_file' do
    HrisIntegrations::Bamboo::UpdateBambooDocumentsFromSaplingJob.new.perform(document_connection, user, 'document_upload_request_file')
    result = document_connection.uploaded_to_bamboo
    expect(result).to eq(true)
  end

  it 'should not execute service UpdateBambooDocumentsFromSaplingJob for document_upload_request_file if user bamboo_id not present' do
    user.update(bamboo_id: nil)
    HrisIntegrations::Bamboo::UpdateBambooDocumentsFromSaplingJob.new.perform(document_connection, user, 'document_upload_request_file')
    result = document_connection.uploaded_to_bamboo
    expect(result).to eq(false)
  end
end
