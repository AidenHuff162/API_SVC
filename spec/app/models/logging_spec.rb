require 'rails_helper'

RSpec.describe Logging, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:integration) }
    it { is_expected.to belong_to(:company) }
  end
end
