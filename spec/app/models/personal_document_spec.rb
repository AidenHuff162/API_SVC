require 'rails_helper'

RSpec.describe PersonalDocument, type: :model do

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:created_by).class_name('User') }
    it { is_expected.to have_one(:attached_file).class_name('UploadedFile::PersonalDocumentFile') }
  end

  describe 'column specifications' do
    it { is_expected.to have_db_column(:title).of_type(:string) }
    it { is_expected.to have_db_column(:description).of_type(:string) }
    it { is_expected.to have_db_column(:deleted_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:user_id).of_type(:integer) }
    it { is_expected.to have_db_column(:created_by_id).of_type(:integer) }

    it { is_expected.to have_db_index(:user_id) }
  end
end