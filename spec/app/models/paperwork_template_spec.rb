require 'rails_helper'

RSpec.describe PaperworkTemplate, type: :model do
  
  let(:company) { create(:company, subdomain: 'paperwork-template-model') }
  let(:document1) { create(:document_with_paperwork_template, company_id: company.id) }
  let(:document2) { create(:document_with_paperwork_request_and_template, company_id: company.id) }
  
  describe 'column specifications' do
    it { is_expected.to have_db_column(:state).of_type(:string) }
    it { is_expected.to have_db_column(:hellosign_template_id).of_type(:string) }
    it { is_expected.to have_db_column(:document_id).of_type(:integer) }
    it { is_expected.to have_db_column(:position).of_type(:integer) }
    it { is_expected.to have_db_column(:company_id).of_type(:integer) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:is_manager_representative).of_type(:boolean) }
    it { is_expected.to have_db_column(:representative_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:user_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:deleted_at).of_type(:datetime).with_options(presence: true) }

    it { is_expected.to have_db_index(:company_id) }
    it { is_expected.to have_db_index(:deleted_at) }
    it { is_expected.to have_db_index(:document_id) }
    it { is_expected.to have_db_index(:representative_id) }
    it { is_expected.to have_db_index(:user_id) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:document) }
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:representative).class_name('User') }
    it { is_expected.to have_many(:paperwork_packet_connections).dependent(:destroy) }
  end

  describe 'attribute accessors' do
    context 'ac#hellosign_template_edit_url' do
      before do
        @paperwork_template = PaperworkTemplate.new
      end

      it 'should have template edit url' do
        @paperwork_template.hellosign_template_edit_url = 'https://somethingnew.com'
        expect(@paperwork_template.hellosign_template_edit_url).to eq('https://somethingnew.com')
      end

      it 'should be blank' do
        expect(@paperwork_template.hellosign_template_edit_url).to be_nil
      end
    end
  end

  describe 'callbacks' do
    context 'after_destroy#remove_document' do
      it 'should destroy document if document has no paperwork requests but paperwork template' do
        expect(document1.paperwork_requests.count).to eq(0)
        paperwork_template = document1.paperwork_template
        paperwork_template.destroy!
        expect(document1.paperwork_template.deleted_at).not_to be_nil
        expect(document1.deleted_at).not_to be_nil
      end

      it 'should destroy paperwork template and document if document has paperwork requests' do
        expect(document2.paperwork_requests.count).to eq(1)
        paperwork_template = document2.paperwork_template
        paperwork_template.destroy!
        expect(document2.paperwork_template.deleted_at).not_to be_nil
      end
    end
  end

  describe 'remove_document' do
    it 'should remove document' do
      paperwork_template = document1.paperwork_template
      paperwork_template.destroy!
      expect(document1.paperwork_template.deleted_at).not_to be_nil
      expect(document1.deleted_at).not_to be_nil
    end
  end

  describe 'hellosign_file_param' do
    it 'hellosign file param' do
      paperwork_template = document1.paperwork_template
      files = paperwork_template.hellosign_file_param
      expect(files.present?).to eq(true)
    end
  end

  describe 'is_cosigned?' do
    it 'return true if cosigned' do
      paperwork_template = document1.paperwork_template
      res = paperwork_template.is_cosigned?
      expect(res).to eq(false)
    end
  end

  describe 'create_hellosign_template' do
    it 'should raise exception with error message on create of hellosign template' do
      paperwork_template = document1.paperwork_template
      res = paperwork_template.create_hellosign_template
      expect(res.first).to eq('An error occured please try again')
    end
  end

  describe 'duplicate_template' do
    let(:user) { create(:user_with_manager_and_policy, :super_admin, company: company) }

    before { User.current = user }

    it 'duplicate hellosign template' do
      allow_any_instance_of(PaperworkTemplate).to receive(:create_hellosign_template).and_return(true)
      paperwork_template = document1.paperwork_template
      res = paperwork_template.duplicate_template
      expect(res.class.name).to eq('PaperworkTemplate')
    end
  end
end
