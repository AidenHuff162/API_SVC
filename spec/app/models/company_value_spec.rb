require 'rails_helper'

RSpec.describe CompanyValue, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to have_one(:company_value_image).class_name('UploadedFile::CompanyValueImage').dependent(:destroy)}
  end
end
