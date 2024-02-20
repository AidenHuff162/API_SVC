require 'rails_helper'

RSpec.describe PtoBalanceAuditLog, type: :model do

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:assigned_pto_policy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:balance_updated_at) }
    it { is_expected.to validate_presence_of(:balance_added) }
    it { is_expected.to validate_presence_of(:assigned_pto_policy_id) }
    it { is_expected.to validate_presence_of(:user_id) }
  end
    
end
