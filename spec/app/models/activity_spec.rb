require 'rails_helper'

RSpec.describe Activity, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:activity) }
    it { is_expected.to belong_to(:agent).class_name('User') }
  end
end