require 'rails_helper'

RSpec.describe UnassignedPtoPolicy, type: :model do

  let(:pto_policy) { FactoryGirl.create(:default_pto_policy) }
  let(:company) { FactoryGirl.create(:company)}
  let(:nick) { FactoryGirl.create(:nick, company: company) }
  let(:unassigned_policy) { FactoryGirl.create(:unassigned_pto_policy, pto_policy: pto_policy, user: nick, effective_date: company.time.to_date) }

  describe 'associations' do
    it { is_expected.to belong_to(:pto_policy) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:effective_date) }
    it { should validate_presence_of(:starting_balance) }
    it { should validate_numericality_of(:starting_balance) }
    it { should validate_uniqueness_of(:user_id).scoped_to(:pto_policy_id) }
  end
    
end
