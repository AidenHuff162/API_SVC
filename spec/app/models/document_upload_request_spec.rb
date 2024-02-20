require 'rails_helper'

RSpec.describe DocumentUploadRequest, type: :model do
  
  describe 'column specifications' do
    it { is_expected.to have_db_column(:company_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:special_user_id).of_type(:integer).with_options(presence: true) }
    it {is_expected.to have_db_column(:global).of_type(:boolean).with_options(presence: true) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(presence: true, null: false) }
    it {is_expected.to have_db_column(:position).of_type(:integer).with_options(presence: true) }
    it {is_expected.to have_db_column(:user_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:deleted_at).of_type(:datetime).with_options(presence: true) }
    it {is_expected.to have_db_column(:document_connection_relation_id).of_type(:integer).with_options(presence: true) }
    
    it { is_expected.to have_db_index(:company_id) }
    it { is_expected.to have_db_index(:deleted_at) }
    it { is_expected.to have_db_index(:document_connection_relation_id) }
    it { is_expected.to have_db_index(:special_user_id) }
    it { is_expected.to have_db_index(:user_id) }
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:special_user).class_name('User') }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:document_connection_relation) }
    it { is_expected.to have_many(:paperwork_packet_connections).dependent(:destroy) }
  end

  describe 'Nested Attributes' do
    it { should accept_nested_attributes_for(:document_connection_relation) }
  end

  describe 'Callbacks - After Destroy' do
    context 'remove relation' do
      let(:company) { create(:company, subdomain: 'documentuploadrequest') }
      let(:document_upload_request) { create(:request_with_connection_relation, company: company) }

      it 'should remove document connection relation if user document connection is not present' do
        document_upload_request.destroy
        expect(DocumentConnectionRelation.count).to eq(0)
      end
    end
  end
end
