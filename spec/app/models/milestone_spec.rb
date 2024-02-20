require 'rails_helper'

RSpec.describe Milestone, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to have_one(:milestone_image) }
  end
end
