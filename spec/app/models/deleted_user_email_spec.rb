require 'rails_helper'

RSpec.describe DeletedUserEmail, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'Validation' do
    describe 'Email' do
      it { is_expected.to validate_presence_of(:email) }
    end

    describe 'Personal Email' do
      it { is_expected.to validate_presence_of(:personal_email) }
    end
  end
end
