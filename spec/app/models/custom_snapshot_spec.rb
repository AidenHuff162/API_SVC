require 'rails_helper'

RSpec.describe CustomSnapshot, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:custom_table_user_snapshot) }
    it { is_expected.to belong_to(:custom_field) }
  end
end
