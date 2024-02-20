require 'rails_helper'

RSpec.describe CompanyValueForm, type: :model do
  describe 'Validation' do
    describe 'Name' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'Description' do
      it { is_expected.to validate_presence_of(:description) }
    end
  end
end
