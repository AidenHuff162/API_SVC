require 'rails_helper'

RSpec.describe PolicyTenureship, type: :model do
  let!(:company) { create(:company) }
  let!(:policy) { create(:default_pto_policy, company: company)}
  describe 'Policy Tenureship create and delete' do
    context 'create ' do
      before do
        @policy_tenureship = FactoryGirl.create(:policy_tenureship, pto_policy: policy)
        policy.reload
      end

      it 'expects that policy have tenureships' do
        expect(policy.policy_tenureships.count).to eq(1)
      end
    end
    context 'delete' do
      before do
        @policy_tenureship = FactoryGirl.create(:policy_tenureship, pto_policy: policy)
        policy.reload
      end

      it 'delete policys tenureship' do
        @policy_tenureship.destroy
        policy.reload
        expect(policy.policy_tenureships.count).to eq(0)
      end
    end

    context 'Checking validations' do

      it 'should not create tenureship with year nil' do
        tenureship = FactoryGirl.build(:policy_tenureship, pto_policy: policy, year: nil)
        expect(tenureship.valid?).to eq(false)
      end

      it 'should not create tenureship with amount nil' do
        tenureship = FactoryGirl.build(:policy_tenureship, pto_policy: policy, amount: nil)
        expect(tenureship.valid?).to eq(false)
      end

      it 'should not create tenureship with amount negative' do
        tenureship = FactoryGirl.build(:policy_tenureship, pto_policy: policy, amount: -2)
        expect(tenureship.valid?).to eq(false)
      end

      it 'should create tenureship with float positive amount' do
        tenureship = FactoryGirl.build(:policy_tenureship, pto_policy: policy, amount: 0.7)
        expect(tenureship.valid?).to eq(true)
      end

      it 'should not create tenureship with amount zero' do
        tenureship = FactoryGirl.build(:policy_tenureship, pto_policy: policy, amount: 0)
        expect(tenureship.valid?).to eq(false)
      end

    end
  end
end
