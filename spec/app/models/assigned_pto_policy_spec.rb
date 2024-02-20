require 'rails_helper'

RSpec.describe AssignedPtoPolicy, type: :model do
  let(:company) { create(:company) }
  subject(:peter) {FactoryGirl.create(:user_with_manager_and_policy, company: company, start_date: company.time.to_date)}
  subject(:nick) {FactoryGirl.create(:user_with_manager_and_policy)}
  
  context 'shoud add acruals for today' do
    it "should accrue balance for today" do
      expect(peter.assigned_pto_policies.first.balance > 0).to eq (true)
    end

    it "should not add  duplicate accrual for today" do
      old_balance = peter.assigned_pto_policies.first.balance
      Pto::ManagePtoBalances.new(0, company, false).perform
      expect( peter.assigned_pto_policies.first.reload.balance).to eq(old_balance)
    end
  end

  describe 'Assigned Pto Policy destroyed and restore' do
    context "On soft delete set balance 0 and log" do
      before do
        @assigned_pto_policy = nick.assigned_pto_policies.first
        @assigned_pto_policy.update_column(:balance, 8)
        @assigned_pto_policy.update_column(:carryover_balance, 8)
        @logs = @assigned_pto_policy.pto_balance_audit_logs
        @assigned_pto_policy.destroy
      end
      it 'should set balance zero' do
        expect(AssignedPtoPolicy.with_deleted.find(@assigned_pto_policy.id).balance).to eq(0)
      end

      it 'should set carryover balance zero' do
        expect(AssignedPtoPolicy.with_deleted.find(@assigned_pto_policy.id).carryover_balance).to eq(0)
      end
      it 'should create a log' do
        expect(AssignedPtoPolicy.with_deleted.find(@assigned_pto_policy.id).pto_balance_audit_logs.with_deleted.size).to eq(@logs.size+1)
      end
    end

    context "On restore set balance 0 and log" do
      before do
        @assigned_pto_policy = nick.assigned_pto_policies.with_deleted.first.destroy
        @assigned_pto_policy.update_column(:balance, 8)
        @assigned_pto_policy.update_column(:carryover_balance, 8)
        @logs_size = @assigned_pto_policy.pto_balance_audit_logs.with_deleted.size
        @assigned_pto_policy.restore(recursive: true)
      end
      it 'should set balance zero' do
        expect(@assigned_pto_policy.balance).to eq(0)
      end

      it 'should set carryover balance zero' do
        expect(@assigned_pto_policy.carryover_balance).to eq(0)
      end
      it 'should create a log' do
        expect(@assigned_pto_policy.pto_balance_audit_logs.size).to eq(@logs_size+1)
      end
    end

    context 'on restore set_accrual_dates' do
      subject(:sam) {FactoryGirl.create(:user, company: company)}
      subject(:pto_policy) {create(:default_pto_policy, unlimited_policy: true, company: company)}
      before { sam.pto_policies << pto_policy}
      it 'should have accrual dates as nil and set the dates after restore if policy is changed to limited' do
        assigned_policy = sam.assigned_pto_policies.first
        expect(assigned_policy.start_of_accrual_period).to eq(nil)
        expect(assigned_policy.first_accrual_happening_date).to eq(nil)
        assigned_policy.destroy
        pto_policy.update(unlimited_policy: false)
        assigned_policy.reload
        assigned_policy.restore
        expect(assigned_policy.reload.start_of_accrual_period).to_not eq(nil)
        expect(assigned_policy.reload.first_accrual_happening_date).to_not eq(nil)
      end

      it 'should have accrual dates as nil and remains so if policy is unlimited' do
        assigned_policy = sam.assigned_pto_policies.first
        assigned_policy.destroy
        assigned_policy.reload
        assigned_policy.restore
        expect(assigned_policy.reload.start_of_accrual_period).to eq(nil)
        expect(assigned_policy.reload.first_accrual_happening_date).to eq(nil)
      end
    end
  end

  context 'Manual Assignment logs' do 
    subject(:tim) {create(:user)}
    subject(:pto_policy) {create(:default_pto_policy, company: tim.company)}

    it 'should have two logs for manualy assigned with balance' do
      assigned_policy = FactoryGirl.create(:assigned_pto_policy, manually_assigned: true, balance: 5, user_id: tim.id, pto_policy_id: pto_policy.id)
      expect(assigned_policy.pto_balance_audit_logs.count).to eq(2)
    end

    it 'should have one log for manualy assigned with balance zero' do
      assigned_policy = FactoryGirl.create(:assigned_pto_policy, manually_assigned: true,user_id: tim.id, pto_policy_id: pto_policy.id)
      expect(assigned_policy.pto_balance_audit_logs.count).to eq(1)
    end
  end

  context 'Start  of accrual date with user start date of past having monthly frequency and accruals at end of period ' do 
    let(:tim) {create(:user, start_date: company.time.to_date - 1.days)}
    let(:pto_policy) {create(:default_pto_policy, company: tim.company, allocate_accruals_at: 1, accrual_frequency: 4)}
    let(:assigned_pto_policy) {create(:assigned_pto_policy, user_id: tim.id, pto_policy_id: pto_policy.id)}
    it 'Should have start_of_accrual date equal to created_at and first accrual happening date equal to end of month' do
      expect(assigned_pto_policy.start_of_accrual_period).to eq(assigned_pto_policy.created_at.in_time_zone(company.time_zone).to_date)
      expect(assigned_pto_policy.first_accrual_happening_date).to eq(assigned_pto_policy.created_at.in_time_zone(company.time_zone).to_date.end_of_month)
    end
  end

  context 'Start  of accrual date with user start date of past having monthly frequency and accruals at start of period ' do 
    let(:tim) {create(:user, start_date: company.time.to_date - 1.days)}
    let(:pto_policy) {create(:default_pto_policy, company: tim.company, allocate_accruals_at: 0, accrual_frequency: 4)}
    let(:assigned_pto_policy) {create(:assigned_pto_policy, user_id: tim.id, pto_policy_id: pto_policy.id)}
    it 'Should have start_of_accrual date equal to created_at and first accrual happening date equal to end of month' do
      accural_date = assigned_pto_policy.created_at.in_time_zone(company.time_zone).to_date
      expect(assigned_pto_policy.start_of_accrual_period).to accural_date.day == 1 ? eq(accural_date.beginning_of_month) : eq(accural_date.next_month.beginning_of_month)
      expect(assigned_pto_policy.first_accrual_happening_date).to accural_date.day == 1 ? eq(accural_date.beginning_of_month) : eq(accural_date.next_month.beginning_of_month)
    end
  end
  
  context 'Start  of accrual date with user start date of future having monthly frequency and accruals at end of period ' do 
    let(:tim) {create(:user, start_date: company.time.to_date + 1.days)}
    let(:pto_policy) {create(:default_pto_policy, company: tim.company, allocate_accruals_at: 1, accrual_frequency: 4)}
    let(:assigned_pto_policy) {create(:assigned_pto_policy, user_id: tim.id, pto_policy_id: pto_policy.id)}
    it 'Should have start_of_accrual date equal to user start_date and first accrual happening date equal to end of month' do
      expect(assigned_pto_policy.start_of_accrual_period).to eq(tim.start_date)
      expect(assigned_pto_policy.first_accrual_happening_date).to eq(tim.start_date.end_of_month)
    end
  end

  context 'Start  of accrual date with user start date of future having monthly frequency and accruals at start of period ' do 
    let(:tim) {create(:user, start_date: company.time.to_date + 1.days)}
    let(:pto_policy) {create(:default_pto_policy, company: tim.company, allocate_accruals_at: 0, accrual_frequency: 4)}
    let(:assigned_pto_policy) {create(:assigned_pto_policy, user_id: tim.id, pto_policy_id: pto_policy.id)}
    it 'Should have start_of_accrual date equal to user start_date and first accrual happening date equal to end of month' do
      expect(assigned_pto_policy.start_of_accrual_period).to eq(tim.start_date)
      expect(assigned_pto_policy.first_accrual_happening_date).to eq(tim.start_date)
    end
  end

  context '#after_update' do
  	context 'changing users start_date on their start_date' do
	  	let!(:user){ create(:user_with_manager_and_policy, :daily_policy, company: company, email: 'someuser@mail.com', personal_email: 'someotheruser@mail.com', start_date: company.time.to_date + 1.days)}
	  	before do
	  		company.update(time_zone: 'UTC')
	  		@assigned_policy = user.assigned_pto_policies.first
	  		time = DateTime.now.utc() + 1.day
	  		DateTime.stub(:now) { time}
	  	end

	  	it 'should not assign initial balance on old start_date' do
	  		Sidekiq::Testing.inline! do
	  			user.update(start_date: user.start_date + 2.days)
	  		end
	  		expect(@assigned_policy.total_balance).to eq(user.reload.assigned_pto_policies.first.total_balance)
	  	end
	  end
  end
end
