require 'rails_helper'

RSpec.describe PtoAdjustment, type: :model do
	subject(:company) {FactoryGirl.create(:company, time_zone: "Pacific Time (US & Canada)")}
  subject(:nick) {FactoryGirl.create(:user_with_manager_and_policy, company: company)}

  describe 'validations' do
  	subject(:adjustment) { build(:pto_adjustment, hours: 8, creator: nick, assigned_pto_policy: nick.assigned_pto_policies.first) }
  	it {should validate_presence_of(:hours) }
  	it {should validate_presence_of(:description) }
  	it {should validate_presence_of(:effective_date) }
  	it {should validate_presence_of(:creator_id) }
  	it {should validate_presence_of(:operation) }
  	it {should validate_presence_of(:assigned_pto_policy_id) }
  	it {should validate_inclusion_of(:is_applied).in_array([true, false]) }
  	it {should validate_numericality_of(:hours) }
  end

  describe 'Pto adjustment create' do
  	context 'Balance updated on pto adjustment of today Date' do
	  	before do
	  		@assigned_pto_policy = nick.assigned_pto_policies.first
	  		@balance = @assigned_pto_policy.balance
	  		@pto_adjustment = FactoryGirl.create(:pto_adjustment, hours: 8, creator: nick, assigned_pto_policy: @assigned_pto_policy)
	  		@assigned_pto_policy.reload
	  		@pto_adjustment.reload
	  	end
	  	it 'should update balance ' do
	  		expect(@assigned_pto_policy.balance).to eq(@balance + @pto_adjustment.hours)
	  	end
	  	it 'should set is_applied true' do
	  		expect(@pto_adjustment.is_applied).to eq(true)
	  	end
  	end

  	context 'Balance updated on pto adjustment of past Date' do
	  	before do
	  		@assigned_pto_policy = nick.assigned_pto_policies.first
	  		@balance = @assigned_pto_policy.balance
	  		@pto_adjustment = FactoryGirl.create(:pto_adjustment, :past_adjustment, hours: 8, creator: nick, assigned_pto_policy: @assigned_pto_policy)
	  		@assigned_pto_policy.reload
	  		@pto_adjustment.reload
	  	end
	  	it 'should update balance ' do
	  		expect(@assigned_pto_policy.balance).to eq(@balance + @pto_adjustment.hours)
	  	end
	  	it 'should set is_applied true' do
	  		expect(@pto_adjustment.is_applied).to eq(true)
	  	end
  	end

  	context 'Balance not updated on pto adjustment of future Date' do
	  	before do
	  		@assigned_pto_policy = nick.assigned_pto_policies.first
	  		@balance = @assigned_pto_policy.balance
	  		@pto_adjustment = FactoryGirl.create(:pto_adjustment, :future_adjustment, hours: 8, creator: nick, assigned_pto_policy: @assigned_pto_policy)
	  		@assigned_pto_policy.reload
	  		@pto_adjustment.reload
	  	end
	  	it 'should not update balance ' do
	  		expect(@assigned_pto_policy.balance).not_to eq(@balance + @pto_adjustment.hours)
	  	end
	  	it 'should not set is_applied true' do
	  		expect(@pto_adjustment.is_applied).not_to eq(true)
	  	end
	  end
  end

  describe 'pto adjustments deletion' do
  	context "adding hours" do
  		let!(:pto_adjustment) {create(:pto_adjustment, creator: nick, hours: 10, assigned_pto_policy: nick.assigned_pto_policies.first, operation: 1)}

	    it 'should add hours to assigned pto policy on creation' do
	      expect(nick.assigned_pto_policies.first.balance).to eq(10)
	    end

	    it 'should deduct hours on deletion if has attr accessor' do
	    	pto_adjustment.deleted_by_user = true
	      pto_adjustment.destroy!
	      expect(nick.assigned_pto_policies.first.balance).to eq(0)
	    end

	    it 'should not deduct hours on deletion if does not have attr accessor' do
	      pto_adjustment.destroy!
	      expect(nick.assigned_pto_policies.first.balance).to eq(10)
	    end
	  end

	  context "subtracting hours" do
  		let!(:pto_adjustment) {create(:pto_adjustment, creator: nick, hours: 10, assigned_pto_policy: nick.assigned_pto_policies.first, operation: 2)}

	    it 'should deduct hours to assigned pto policy on creation' do
	      expect(nick.assigned_pto_policies.first.balance).to eq(-10)
	    end

	    it 'should add hours on deletion if has attr accessor' do
	    	pto_adjustment.deleted_by_user = true
	      pto_adjustment.destroy!
	      expect(nick.assigned_pto_policies.first.balance).to eq(0)
	    end

	    it 'should not add hours on deletion if does not have attr accessor' do
	      pto_adjustment.destroy!
	      expect(nick.assigned_pto_policies.first.balance).to eq(-10)
	    end
	  end
  end
end
