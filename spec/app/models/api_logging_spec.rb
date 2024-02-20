require 'rails_helper'

RSpec.describe ApiLogging, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:company) }
  end
end
