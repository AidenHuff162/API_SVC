require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:edited_by).class_name('User') }
  end

  describe 'Validation' do
    describe 'Name' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'Encrypted Key' do
      it { is_expected.to validate_presence_of(:encrypted_key) }
    end

    describe 'Encrypted Key IV' do
      it { is_expected.to validate_presence_of(:encrypted_key_iv) }
    end
  end
end
