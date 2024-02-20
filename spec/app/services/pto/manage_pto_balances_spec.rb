require 'rails_helper'

RSpec.describe Pto::ManagePtoBalances do
  let(:company) { create(:company, subdomain: 'rocketspace', enabled_calendar: true) }
  let(:user) {create(:user, company: company)}

  describe 'Policy with accrual at the end of period' do 
    let(:pto_policy) {create(:default_pto_policy, company: company)}
    before do 
      user.pto_policies << pto_policy
      @assigned_policy = user.assigned_pto_policies.first 
    end
    context 'First accrual Happen' do
      
      before do  
        Pto::ManagePtoBalances.new(1, company, true, @assigned_policy.first_accrual_happening_date).add_initial_balance_for_policy_starting_at_custom_accrual_date
      end
      
      it 'should do first accrual on first accrual happening date' do 
        expect(@assigned_policy.reload.balance > 0).to eq(true)
      end

      it 'should update the is_balance_calculated_before to true' do
        expect(@assigned_policy.reload.is_balance_calculated_before).to eq(true)
      end

      it 'should have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(1)
      end

      it 'should set balance_updated_at to accrual date' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(@assigned_policy.first_accrual_happening_date)
      end
    end

    context 'First accrual should not Happen' do
      
      before do  
        Pto::ManagePtoBalances.new(1, company, true, @assigned_policy.first_accrual_happening_date - 1.days).add_initial_balance_for_policy_starting_at_custom_accrual_date
      end
      
      it 'should not do first accrual before first accrual happening date' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not update the is_balance_calculated_before to true' do
        expect(@assigned_policy.reload.is_balance_calculated_before).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end

      it 'should not update balance_updated_at ' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'First accrual Happen after date has passed' do
      
      before do  
        Pto::ManagePtoBalances.new(1, company, true, @assigned_policy.first_accrual_happening_date + 1.days).add_initial_balance_for_policy_starting_at_custom_accrual_date
      end
      
      it 'should do first accrual after first accrual happening date' do 
        expect(@assigned_policy.reload.balance > 0).to eq(true)
      end

      it 'should update the is_balance_calculated_before to true' do
        expect(@assigned_policy.reload.is_balance_calculated_before).to eq(true)
      end

      it 'should have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(1)
      end

      it 'should set baalnce_updated_at to current date' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(@assigned_policy.first_accrual_happening_date + 1.days)
      end
    end

    context 'First accrual for unlimited policy' do
      
      before do  
        pto_policy.update(unlimited_policy: true)
        Pto::ManagePtoBalances.new(1, company, true, @assigned_policy.first_accrual_happening_date).add_initial_balance_for_policy_starting_at_custom_accrual_date
      end
      
      it 'should not do first accrual for unlimited policy' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not update the is_balance_calculated_before to true' do
        expect(@assigned_policy.reload.is_balance_calculated_before).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end
      
      it 'should not update balance_updated_at ' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'First Accrual for assigned policy whose balance is calculated before' do
      
      before do  
        @assigned_policy.update(is_balance_calculated_before: true)
        Pto::ManagePtoBalances.new(1, company, true, @assigned_policy.first_accrual_happening_date).add_initial_balance_for_policy_starting_at_custom_accrual_date
      end
      
      it 'should not do first accrual for policy whose balance is calculated before' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end
      
      it 'should not update balance_updated_at ' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'Regular accrual  at end of period ' do
      
      before do
        @assigned_policy.update(is_balance_calculated_before: true)  
        Pto::ManagePtoBalances.new(1, company, true, @assigned_policy.first_accrual_happening_date.end_of_week.to_date + 7.days).perform
      end
      
      it 'should do regular accrual on the end of period' do 
        expect(@assigned_policy.reload.balance > 0).to eq(true)
      end

      it 'should update the is_balance_calculated_before to true' do
        expect(@assigned_policy.reload.is_balance_calculated_before).to eq(true)
      end

      it 'should have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(1)
      end

      it 'should set baalnce_updated_at to current date' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(@assigned_policy.first_accrual_happening_date.end_of_week.to_date + 7.days)
      end
    end

    context 'Regular accrual at start of period ' do
      
      before do
        @assigned_policy.update(is_balance_calculated_before: true)  
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.first_accrual_happening_date.beginning_of_week.to_date  + 7.days).perform
      end
      
      it 'should not do regular accrual on the start of period' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end

      it 'should not set balance' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'Regular accrual before first_accrual_happening_date ' do
      
      before do
        @assigned_policy.update(is_balance_calculated_before: true)  
        Pto::ManagePtoBalances.new(1, company, true, @assigned_policy.first_accrual_happening_date.end_of_week.to_date - 7.days).perform
      end
      
      it 'should not do regular accrual on the before first_accrual_happening_date' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end

      it 'should not set balance_updated_at' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'Regular accrual for unlimited_policy' do
      
      before do
        @assigned_policy.update(is_balance_calculated_before: true)  
        Pto::ManagePtoBalances.new(1, company, true, @assigned_policy.first_accrual_happening_date.beginning_of_week.to_date + 7.days).perform
      end
      
      it 'should not do regular accrual on the for unlimited_policy' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end

      it 'should not set balance_updated_at' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'Regular accrual for policy whose is_balance_calculated_before is false' do
      
      before do
        Pto::ManagePtoBalances.new(1, company, true, @assigned_policy.first_accrual_happening_date.end_of_week.to_date + 7.days).perform
      end
      
      it 'should not do regular accrual for policy whose is_balance_calculated_before is false' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end

      it 'should not set balance_updated_at' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end
  end

  describe 'Policy with accrual at the start of period with user start date not of today' do 
    let(:pto_policy) {create(:default_pto_policy, :accruals_at_start, company: company)}
    before do 
      user.pto_policies << pto_policy
      @assigned_policy = user.assigned_pto_policies.first 
    end
    context 'First accrual Happen' do
      
      before do  
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.start_of_accrual_period).add_initial_balance_for_policy_starting_at_custom_accrual_date
      end
      
      it 'should do first accrual on first accrual happening date' do 
        expect(@assigned_policy.reload.balance > 0).to eq(true)
      end

      it 'should update the is_balance_calculated_before to true' do
        expect(@assigned_policy.reload.is_balance_calculated_before).to eq(true)
      end

      it 'should have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(1)
      end

      it 'should set balance_updated_at to accrual date' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(@assigned_policy.start_of_accrual_period)
      end
    end

    context 'First accrual should not Happen' do
      
      before do  
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.start_of_accrual_period - 1.days).add_initial_balance_for_policy_starting_at_custom_accrual_date
      end
      
      it 'should not do first accrual before start of accrual period' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not update the is_balance_calculated_before to true' do
        expect(@assigned_policy.reload.is_balance_calculated_before).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end

      it 'should not update balance_updated_at ' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'First accrual Happen after date has passed' do
      
      before do  
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.start_of_accrual_period + 1.days).add_initial_balance_for_policy_starting_at_custom_accrual_date
      end
      
      it 'should do first accrual after start of accrual date' do 
        expect(@assigned_policy.reload.balance > 0).to eq(true)
      end

      it 'should update the is_balance_calculated_before to true' do
        expect(@assigned_policy.reload.is_balance_calculated_before).to eq(true)
      end

      it 'should have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(1)
      end

      it 'should set balance_updated_at to current date' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(@assigned_policy.start_of_accrual_period + 1.days)
      end
    end

    context 'First accrual for unlimited policy' do
      
      before do  
        pto_policy.update(unlimited_policy: true)
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.start_of_accrual_period).add_initial_balance_for_policy_starting_at_custom_accrual_date
      end
      
      it 'should not do first accrual for unlimited policy' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not update the is_balance_calculated_before to true' do
        expect(@assigned_policy.reload.is_balance_calculated_before).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end
      
      it 'should not update balance_updated_at ' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'First Accrual for assigned policy whose balance is calculated before' do
      
      before do  
        @assigned_policy.update(is_balance_calculated_before: true)
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.start_of_accrual_period).add_initial_balance_for_policy_starting_at_custom_accrual_date
      end
      
      it 'should not do first accrual for policy whose balance is calculated before' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end
      
      it 'should not update balance_updated_at ' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'Regular accrual  at start of period ' do
      
      before do
        @assigned_policy.update(is_balance_calculated_before: true)  
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.start_of_accrual_period.beginning_of_week.to_date + 7.days).perform
      end
      
      it 'should do regular accrual on the end of period' do
        expect(@assigned_policy.reload.balance > 0).to eq(true)
      end

      it 'should do regular accrual of amount' do
        expect(@assigned_policy.reload.balance.round(2)).to eq(0.15)
      end

      it 'should update the is_balance_calculated_before to true' do
        expect(@assigned_policy.reload.is_balance_calculated_before).to eq(true)
      end

      it 'should have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(1)
      end

      it 'should set balance_updated_at to current date' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(@assigned_policy.start_of_accrual_period.beginning_of_week.to_date + 7.days)
      end


    end

    context 'Regular accrual at end of period ' do
      
      before do
        @assigned_policy.update(is_balance_calculated_before: true)  
        Pto::ManagePtoBalances.new(1, company, true, @assigned_policy.start_of_accrual_period.end_of_week.to_date  + 7.days).perform
      end
      
      it 'should not do regular accrual on the start of period' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end

      it 'should not set balance_updated_at' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'Regular accrual before start_of_accrual_period ' do
      
      before do
        @assigned_policy.update(is_balance_calculated_before: true)  
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.start_of_accrual_period.end_of_week.to_date - 7.days).perform
      end
      
      it 'should not do regular accrual on the before start_of_accrual_period' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end

      it 'should not set baalnce updated at' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'Regular accrual for unlimited_policy' do
      
      before do
        pto_policy.update(unlimited_policy: true)
        @assigned_policy.update(is_balance_calculated_before: true)  
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.start_of_accrual_period.beginning_of_week.to_date + 7.days).perform
      end
      
      it 'should not do regular accrual on the for unlimited_policy' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end

      it 'should not set baalnce updated at' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end

    context 'Regular accrual for policy whose is_balance_calculated_before is false' do
      
      before do
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.start_of_accrual_period.beginning_of_week.to_date + 7.days).perform
      end
      
      it 'should not do regular accrual for policy whose is_balance_calculated_before is false' do 
        expect(@assigned_policy.reload.balance > 0).to eq(false)
      end

      it 'should not have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(0)
      end

      it 'should not set baalnce updated at' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(nil)
      end
    end
  end

  describe 'Accrual for start of period when user start date is today' do
    let!(:pto_policy) {create(:default_pto_policy, :accruals_at_start, company: company)}
    let(:tim) {create(:user, start_date: company.time.to_date, company: company)}
    before do 
      tim.pto_policies << pto_policy
      @assigned_policy = tim.assigned_pto_policies.first 
    end

    context 'Policy assigned on start date' do
      it 'should have first_accrual_happening_date of user start date' do
        expect(@assigned_policy.first_accrual_happening_date).to eq(tim.start_date)
      end

      it 'should have balance accrued' do
        expect(@assigned_policy.balance > 0).to eq(true)
      end

      it 'should have logs for the accrual' do
        expect(@assigned_policy.pto_balance_audit_logs.where("description LIKE 'Accr%'").size).to eq(1)
      end

      it 'should set baalnce updated at to user start_date' do
        expect(@assigned_policy.reload.balance_updated_at).to eq(tim.start_date)
      end
    end
  end

  describe 'Stop Accrual after particular time period' do
    let!(:pto_policy) {create(:default_pto_policy, :accruals_at_start, :policy_has_stop_accrual_date, company: company)}
    let(:tim) {create(:user, start_date: company.time.to_date, company: company)}
    before do 
      tim.pto_policies << pto_policy
      @assigned_policy = tim.assigned_pto_policies.first 
    end
    context 'Stop accrual after time period' do
      it 'should have balance accrued before time period' do
        Pto::ManagePtoBalances.new(0, company, true, @assigned_policy.start_of_accrual_period.beginning_of_week.to_date + 7.days).perform
        expect(@assigned_policy.balance > 0).to eq(true)
      end
      it 'should not have balance accrued after time period' do
        balance = @assigned_policy.balance
        Pto::ManagePtoBalances.new(0, company, true, user.start_date.beginning_of_week + 70.days).perform
        expect(@assigned_policy.reload.balance).to eq(balance)
      end
    end
  end
end
