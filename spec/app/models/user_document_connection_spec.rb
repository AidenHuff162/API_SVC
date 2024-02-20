require 'rails_helper'

RSpec.describe UserDocumentConnection, type: :model do
  subject(:company) {FactoryGirl.create(:company, notifications_enabled: true, preboarding_complete_emails: true)}
  subject(:sarah) {FactoryGirl.create(:sarah, company: company)}
  subject(:attachment) {FactoryGirl.create(:document_upload_request_file)}
  subject(:user_document_connection) { create(:user_document_connection, user: sarah, created_by: sarah, document_connection_relation: FactoryGirl.create(:document_connection_relation), attached_files: [attachment]) }

  describe 'Associations' do
    it { is_expected.to belong_to(:user).counter_cache}
    it { is_expected.to belong_to(:created_by).class_name('User')}
    it { is_expected.to belong_to(:document_connection_relation) }

    it { is_expected.to have_many(:attached_files).class_name('UploadedFile::DocumentUploadRequestFile')}
  end

  describe 'After create' do
    it 'must enable activity notification' do
      expect(sarah.document_seen).to eq(false)
    end
  end

  describe 'send document to integrations' do
    before do
      @sarah = sarah
      @document = user_document_connection
      @document.save!
    end

    it 'should perform job' do
      Sidekiq::Testing.inline! do
        expect(@document.attached_files.size).to eq(1)
      end
    end
  end

end
