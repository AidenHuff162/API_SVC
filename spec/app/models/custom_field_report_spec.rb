require 'rails_helper'

RSpec.describe CustomFieldReport, type: :model do

  describe 'Associations' do
    it { is_expected.to belong_to(:custom_field) }
    it { is_expected.to belong_to(:report) }
  end
end