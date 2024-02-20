require 'rails_helper'

RSpec.describe CompanyLinkForm, type: :model do
  describe 'Validation' do
    describe 'Name' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'Link' do
      it { is_expected.to validate_presence_of(:link) }
    end

    describe 'Position' do
      it { is_expected.to validate_presence_of(:position) }
    end
  end
end
