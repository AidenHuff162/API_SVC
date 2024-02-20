require 'rails_helper'

RSpec.describe MilestoneForm, type: :model do
  describe 'Validation' do
    describe 'Name' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'Happened at' do
      it { is_expected.not_to validate_presence_of(:happened_at) }
    end

    describe 'Description' do
      it { is_expected.not_to validate_presence_of(:description) }
    end

    describe 'Milestone image' do
      it { is_expected.not_to validate_presence_of(:milestone_image) }
    end
  end
end
