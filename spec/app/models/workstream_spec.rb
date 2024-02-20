require 'rails_helper'

RSpec.describe Workstream, type: :model do
  subject(:workstream) { create(:workstream) }

  describe 'Validation' do
    describe 'Name' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'Company' do
      it { is_expected.to validate_presence_of(:company) }
    end
  end

  describe 'Associations' do
    it { is_expected.to have_many(:tasks) }
    it { is_expected.to belong_to(:company) }
  end
end
