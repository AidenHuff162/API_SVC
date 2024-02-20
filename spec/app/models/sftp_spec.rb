require 'rails_helper'

RSpec.describe Sftp, type: :model do
  let(:company) { create(:company) }
  let(:super_admin) { create(:sarah, company: company) }

  describe 'column specifications' do
    it { is_expected.to have_db_column(:name).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:host_url).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:authentication_key_type).of_type(:integer).with_options(null: false, default: 'credentials') }
    it { is_expected.to have_db_column(:user_name).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:encrypted_password).of_type(:string).with_options(null: true) }
    it { is_expected.to have_db_column(:port).of_type(:integer).with_options(null: false) }
    it { is_expected.to have_db_column(:updated_by_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:folder_path).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:company_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(null: false) }
    it { is_expected.to have_db_column(:deleted_at).of_type(:datetime).with_options(presence: true) }
    it { is_expected.to have_db_column(:encrypted_password_iv).of_type(:string).with_options(null: true) }

    it { is_expected.to have_db_index(:company_id) }
    it { is_expected.to have_db_index(:updated_by_id) }
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:company)}
    it { is_expected.to belong_to(:updater).class_name('User')}
    it { is_expected.to have_one(:public_key).class_name('UploadedFile::SftpPublicKey')}

  end

  describe 'Enums' do
    it { should define_enum_for(:authentication_key_type).with([:credentials, :public_key]) }
  end

  describe 'callbacks' do
    context 'before save #remove_password' do
      before do
        @request = create(:sftp, updated_by_id: super_admin.id, company: company, password: 'admin123', authentication_key_type: 'public_key' )  
      end

      it 'should set password to nil  when authentication_key_type is Public_key' do
        expect(@request.password).to eq(nil)
      end
    end

    context 'before save #remove_password' do
      before do
        @request = create(:sftp, updated_by_id: super_admin.id, company: company, password: 'admin123', authentication_key_type: 'credentials' )
      end

      it 'should not set password to nil  when authentication_key_type is Credentials' do
        expect(@request.password).to eq('admin123')
      end
    end
  end
end
