require 'rails_helper'

RSpec.describe CompanyEmail, type: :model do
  let(:user_email) { create(:user_email) }
  let(:company_email) { create(:company_email, to: ['sarah@test.com'], cc: ['sarah@test.com'], bcc: ['sarah@test.com']) }
  let(:company_email2) { create(:company_email) }

  describe 'Associations' do
    it { is_expected.to have_many(:attachments).class_name('UploadedFile::Attachment') }
    it { is_expected.to belong_to(:company) }
  end

  describe 'Business logic' do
    it 'Tests sent_to model function' do
      expect(CompanyEmail.sent_to('sarah@test.com')).to be_truthy
    end

    it 'Tests sent_to model function when value is not present' do
      expect(CompanyEmail.sent_to('janedoe@test.com')).to match_array([])
    end

    it 'Tests cc_email model function' do
      expect(CompanyEmail.cc_email('sarah@test.com')).to be_truthy
    end

    it 'Tests cc_email model function when value is not present' do
      expect(CompanyEmail.cc_email('janedoe@test.com')).to match_array([])
    end

    it 'Tests bcc_email model function' do
      expect(CompanyEmail.bcc_email('sarah@test.com')).to be_truthy
    end

    it 'Tests bcc_email model function when value is not present' do
      expect(CompanyEmail.bcc_email('janedoe@test.com')).to match_array([])
    end
  end
end