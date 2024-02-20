require 'rails_helper'

RSpec.describe Document, type: :model do

   describe 'column specifications' do
    it { is_expected.to have_db_column(:company_id).of_type(:integer).with_options(presence: true) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(presence: true, null: false) }
    it { is_expected.to have_db_column(:title).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:description).of_type(:text).with_options(presence: true) }
    it { is_expected.to have_db_column(:deleted_at).of_type(:datetime).with_options(presence: true) }

    it { is_expected.to have_db_index(:company_id) }
    it { is_expected.to have_db_index(:deleted_at) }
  end


  describe 'Associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to have_many(:paperwork_requests).dependent(:destroy) }
    it { is_expected.to have_one(:paperwork_template).dependent(:destroy) }
    it { is_expected.to have_one(:attached_file).class_name('UploadedFile::DocumentFile') }
  end
end
