require 'rails_helper'

RSpec.describe Pto::RenewPtoPolicies do

  let(:company) { create(:company, enabled_time_off: true) }
  let(:user) { create(:user, company: company, start_date: company.time.to_date) }

  describe "negative carryover allowed and no max carryover" do
    let(:policy_with_negative_without_max) { create(:default_pto_policy, :policy_with_negative_carryover_without_max_carryover, accrual_renewal_time: "anniversary_date", accrual_rate_amount: 0, company: company) }

    context 'positive balance' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_with_negative_without_max, balance: 20, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should set positive balance as zero and set carryover balance equal to balance" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(20)
      end
    end

    context 'negative balance' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_with_negative_without_max, balance: -20, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should keep negative balance as negative and set carryover balance equal to 0 " do
        expect(@assigned_policy.balance).to eq(-20)
        expect(@assigned_policy.carryover_balance).to eq(0)
      end
    end
  end

  describe 'max carryover balance and allowed negative carryover balance' do
    let(:policy_with_negative_with_max) { create(:default_pto_policy, :policy_with_negative_carryover_with_max_carryover, accrual_rate_amount: 0, accrual_renewal_time: "anniversary_date", company: company) }
    context 'policy with balance greater than max' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_with_negative_with_max, balance: 20, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      
      it "should set positive balance as zero and set carryover balance equal to max carryover balanc" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(8)
      end
    end

    context 'policy with balance less than max' do
      before do 
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_with_negative_with_max, balance: 5, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should set positive balance as zero and set  carryover balance equal to balance if less than max" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(5)
      end
    end

    context 'policy with balance equal max' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_with_negative_with_max, balance: 8, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should set positive balance as zero and set carryover balance equal to balance if equal to max" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(8)
      end
    end

    context 'policy with balance negative' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_with_negative_with_max, balance: -20, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end

      it "should keep negative balance as negative and set carryover balance equal to 0" do
        expect(@assigned_policy.balance).to eq(-20)
        expect(@assigned_policy.carryover_balance).to eq(0)
      end
    end
  end

  describe 'negative carryover is not allowed and no max carryover' do
    let(:policy_without_negative_without_max) { create(:default_pto_policy, :policy_without_negative_carryover_without_max_carryover, accrual_rate_amount: 0, accrual_renewal_time: "anniversary_date", company: company) }

    context 'negatve balance' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_negative_without_max, balance: -20, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should set negative balance as zero and set carryover balance equal to zero" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(0)
      end
    end

    context 'negatve balance' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_negative_without_max, balance: 20, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end

      it "should set positive balance as zero and set carryover balance equal to balance" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(20)
      end
    end
  end

  describe 'negative carryover is not allowed and max carryover set' do
    let(:policy_without_negative_with_max) { create(:default_pto_policy, :policy_without_negative_carryover_with_max_carryover, accrual_rate_amount: 0, accrual_renewal_time: "anniversary_date", company: company) }

    context 'policy with balance greater than max' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_negative_with_max, balance: 20, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should set positive balance as zero and set carryover balance equal to max carryover balance" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(8)
      end
    end
    
    context 'policy with balance less than max' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_negative_with_max, balance: 5, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should set positive balance as zero and set carryover balance equal to balance if less than max" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(5)
      end
    end
    
    context 'policy with balance equal to max' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_negative_with_max, balance: 8, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end

      it "should set positive balance as zero and set carryover balance equal to balance if equal to max" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(8)
      end
    end

    context 'negative balance' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_negative_with_max, balance: -20, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should set negative balance as zero and set carryover balance equal to 0" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(0)
      end
    end
  end

  describe 'carryover balance not allowed' do
    let(:policy_without_carryover) { create(:default_pto_policy, :policy_without_carryover, accrual_rate_amount: 0, carry_over_negative_balance: false, accrual_renewal_time: "anniversary_date", company: company) }

    context 'positive balance' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_carryover, balance: 20, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should set positive balance as zero and set carryover balance equal to zero" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(0)
      end
    end      

    context 'negative balance' do
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_carryover, balance: -20, carryover_balance: 0)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should set negative balance as zero and set carryover balance equal to zero" do
        expect(@assigned_policy.balance).to eq(0)
        expect(@assigned_policy.carryover_balance).to eq(0)
      end
    end
  end

  describe 'balance on renewal' do

    context 'anniversary/yearly' do
      let(:policy_without_carryover) { create(:default_pto_policy, :policy_without_carryover, accrual_rate_amount: 1, carry_over_negative_balance: false, accrual_renewal_time: "anniversary_date", company: company, accrual_frequency: 5) }
      it "should accrue balance for yearly policy" do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_carryover, balance: 20, carryover_balance: 0, is_balance_calculated_before: true, balance_updated_at: 3.day.ago)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
        expect(@assigned_policy.balance).to_not eq(0)
      end

      it "should not accrue first balance for yearly policy" do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_carryover, balance: 20, carryover_balance: 0, balance_updated_at: 3.day.ago)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
        expect(@assigned_policy.balance).to eq(0)
      end

      it "should not accrue if balance updated is today's date for yearly policy" do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_carryover, balance: 20, carryover_balance: 0, is_balance_calculated_before: true, balance_updated_at: user.start_date)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
        expect(@assigned_policy.balance).to eq(0)
      end
    end      

    context 'anniversary/not_yearly' do
      let(:policy_without_carryover) { create(:default_pto_policy, :policy_without_carryover, accrual_rate_amount: 1, carry_over_negative_balance: false, accrual_renewal_time: "anniversary_date", company: company) }
      before do
        @assigned_policy = FactoryGirl.create(:assigned_pto_policy, user: user, pto_policy: policy_without_carryover, balance: 20, carryover_balance: 0, is_balance_calculated_before: true, balance_updated_at: 3.day.ago)
        Pto::RenewPtoPolicies.new.perform(company.id)
        @assigned_policy.reload
      end
      it "should not accrue balance for other policies" do
        expect(@assigned_policy.balance).to eq(0)
      end
    end 
  end
end
