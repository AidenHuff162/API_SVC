require 'rails_helper'

RSpec.describe DocumentConnectionRelationForm, type: :model do
  describe 'Validation' do
    describe 'Title' do
      it { is_expected.to validate_presence_of(:title) }
    end

    describe 'Description' do
      it { is_expected.to validate_presence_of(:description) }
    end
  end
end
