require 'rails_helper'
require "sidekiq/testing"

RSpec.describe PtoRequest, type: :model do
  let(:company) {create(:company, enabled_time_off: true)}
  let!(:nick) {FactoryGirl.create(:user_with_manager_and_policy, start_date: company.time.to_date - 2.year, company: company)}

  before do
    stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
    User.current = nick
  end

  describe 'rails validations' do
    subject(:pto) {create(:default_pto_request, user: nick, pto_policy: nick.pto_policies.first)}
    it { should validate_presence_of(:begin_date) }
    it { should validate_presence_of(:end_date) }
    it { should validate_inclusion_of(:partial_day_included).in?([true, false]) }
  end

  describe 'associations' do
  	subject(:pto_request) { create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id) }
    it { should have_many(:attachments).class_name('UploadedFile::Attachment').dependent(:destroy) }
  end

  describe 'after create' do
    it 'should create a hash_id for that pto request' do
      pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      expect(pto_request.hash_id).not_to be_nil
    end

    it 'should send email on pto request create.' do
      Sidekiq::Testing.inline! do
        expect{FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}.to change{ CompanyEmail.all.count }.by(1)
      end
    end
  end

  describe 'changing state from approved/denied to pending' do
    it 'should add hash_id on changing from approved to pending' do
      pto_request = FactoryGirl.create(:default_pto_request, :approved_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      pto_request.status = "pending"
      pto_request.save
      expect(pto_request.hash_id).not_to be_nil
    end

    it 'should add hash_id on changing from denied to pending' do
      pto_request = FactoryGirl.create(:default_pto_request, :denied_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      pto_request.status = "pending"
      pto_request.save
      expect(pto_request.hash_id).not_to be_nil
    end
  end

  describe 'changing state from pending to approved/denied' do
    it 'should update hash_id from the pto_request when changed from pending to approved' do
      pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      pto_request.status = "approved"
      old_hash = pto_request.hash_id
      pto_request.save
      expect(pto_request.reload.hash_id).to_not eq(old_hash)
    end

    it 'should update hash_id from the pto_request when changed from pending to denied' do
      pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      pto_request.status = "denied"
      old_hash = pto_request.hash_id
      pto_request.save
      expect(pto_request.reload.hash_id).to_not eq(old_hash)
    end
  end

  describe 'Updating policy balance on Pto Request' do
    before do
      @assigned_policy = nick.assigned_pto_policies.find_by(pto_policy_id: nick.pto_policies.first.id)
      @policy_balance = @assigned_policy.balance
      @date = nick.company.time.to_date
      @past_date_this_year = @date == @date.beginning_of_year ? @date : @date - 1.days
      @past_date_not_this_year = @date - 1.year
      @future_date = @date + 1.days
    end
    context 'should deduct pto hours amount from assigned pto balance If request is of today' do
      before  do
        @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: @assigned_policy.pto_policy_id, begin_date: @date, end_date: @date)
        @assigned_policy.reload
      end

      it 'should deduct balance' do 
        expect(@assigned_policy.balance.round(2)).to eq((@policy_balance - @pto_request.balance_hours).round(2))
      end

      it 'should set deduct_balance true' do 
        expect(@pto_request.balance_deducted).to eq(true)
      end
    end

    context 'should deduct pto hours amount from assigned pto balance If request is of past this year' do
      before do
        @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: @assigned_policy.pto_policy_id, begin_date: @past_date_this_year, end_date: @past_date_this_year)
        @assigned_policy.reload
      end
      
      it 'should deduct balance' do 
        expect(@assigned_policy.balance.round(5)).to eq((@policy_balance - @pto_request.balance_hours).round(5))
      end

      it 'should set deduct_balance true' do 
        expect(@pto_request.balance_deducted).to eq(true)
      end
    end

    context 'should not deduct pto hours amount from assigned pto balance If request is of past and not this year' do
      before do 
        @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: @assigned_policy.pto_policy_id, begin_date: @past_date_not_this_year, end_date: @past_date_not_this_year)
        @assigned_policy.reload
      end
      it 'should not deduct balance' do
        expect(@assigned_policy.balance).not_to eq(@policy_balance - @pto_request.balance_hours)
        expect(@assigned_policy.balance).to eq(@policy_balance)
      end
      it 'should not set deduct_balance true' do 
        expect(@pto_request.balance_deducted).to eq(false)
      end
    end

    context 'should not deduct pto hours amount from assigned pto balance If request is of future' do
      before do
        @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: @assigned_policy.pto_policy_id, begin_date: @future_date, end_date: @future_date)
        @assigned_policy.reload
      end
      it 'should not deduct balance' do
        expect(@assigned_policy.balance).not_to eq(@policy_balance - @pto_request.balance_hours)
        expect(@assigned_policy.balance).to eq(@policy_balance)
      end
      it 'should notset deduct_balance true' do 
        expect(@pto_request.balance_deducted).to eq(false)
      end
    end

    context 'change in partial hours' do
      let!(:pto)  {create(:default_pto_request, user_id: nick.id, pto_policy_id: @assigned_policy.pto_policy_id, begin_date: @date, end_date: @date, balance_hours: 8)}

      it 'should add back extra balance back' do
        expect{pto.update(partial_day_included: true, balance_hours: 7)}.to change{@assigned_policy.reload.balance}.by(1)
      end

      it 'should not add back extra balance back' do
        expect{pto.update(partial_day_included: true)}.to change{@assigned_policy.reload.balance}.by(0)
      end

      it 'should not deduct extra balance back' do
        pto.update(partial_day_included: true, balance_hours: 6)
        expect{pto.update(balance_hours: 7)}.to change{@assigned_policy.reload.balance}.by(-1)
      end
    end
  end

  describe 'Making Pto request for past dates' do
    it 'should make pto request on past dates' do
      pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id, begin_date: (Time.now-2.days), end_date: (Time.now-2.days))
      expect(pto_request.errors.messages.count).to eq(0)
    end

    context 'updating request to past' do
      before do
        @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      end
      
      it 'should update pto request to past dates of current years and balance_deducted should be true' do
        @pto_request.update( begin_date: company.time.beginning_of_year.to_date, end_date: company.time.beginning_of_year.to_date)
        expect(@pto_request.errors.messages.count).to eq(0)
        expect(@pto_request.reload.balance_deducted).to eq(true)
      end

      it 'should update pto request to past dates of current years and balance_deducted should be false' do
        @pto_request.update( begin_date: company.time.beginning_of_year.to_date - 2.days, end_date: company.time.beginning_of_year.to_date -  2.days)
        expect(@pto_request.errors.messages.count).to eq(0)
        expect(@pto_request.reload.balance_deducted).to eq(false)
      end
    end
  end

  describe "updating pto_request" do
    before do
      @assigned_policy = nick.assigned_pto_policies.find_by(pto_policy_id: nick.pto_policies.first.id)
      @date = nick.company.time.to_date
      @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: @assigned_policy.pto_policy_id, begin_date: @date, end_date: @date)
      @policy_balance = @assigned_policy.reload.balance
      @old_amount = @pto_request.balance_hours
    end

    it "should update assigned policy balance on update in pto request" do
      @pto_request.update(end_date: (@date + 1.day))
      expect(@assigned_policy.reload.balance).to eq(@policy_balance + @old_amount - @pto_request.reload.balance_hours)
    end

    it "should only add back balance to assigned policy balance on update in pto request to other year" do
      @pto_request.update(begin_date: (@date + 1.year), end_date: (@date + 1.year))
      expect(@assigned_policy.reload.balance.round(5)).to eq((@policy_balance + @old_amount).round(5))
    end

    it "should update add balance back to assigned policy balance on denying pto request" do
      @pto_request.update(status: 2)
      expect(@assigned_policy.reload.balance.round(5)).to eq((@policy_balance + @pto_request.reload.balance_hours).round(5))
    end

    it "should update add balance back to assigned policy balance on canceling pto request" do
      @pto_request.update(status: 3)
      expect(@assigned_policy.reload.balance.round(5)).to eq((@policy_balance + @pto_request.reload.balance_hours).round(5))
    end

  end

  describe 'Pto request of multiple days with partial days' do

    it 'should not throw error on Pto request of single day with partial days for policy with tracking unit daily and half day allowed' do
      pto_request = FactoryGirl.build(:default_pto_request, :partial_day_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id, partial_day_included: true)
      expect(pto_request.valid?).to eq(true)
    end

    it 'should throw error on Pto request of multiple days with partial days for policy with tracking unit daily and half day allowed' do
      pto_request = FactoryGirl.build(:default_pto_request, :request_with_multiple_days, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id, partial_day_included: true)
      expect(pto_request.valid?).to eq(false)
    end

    it 'should throw error on Pto request for policy with tracking unit daily and half day not allowed' do
      pto_policy = nick.pto_policies.first
      pto_policy.update_column(:half_day_enabled, false)
      pto_request = FactoryGirl.build(:default_pto_request, :partial_day_request, user_id: nick.id, pto_policy_id: pto_policy.id , partial_day_included: true)
      expect(pto_request.valid?).to eq(false)
    end

  end

  describe 'PTO requests with disabled policy' do
    before do 
      @pto_policy = nick.pto_policies.first
      @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      @pto_policy.update(is_enabled: false)
      @pto_request.reload
    end

    it 'should not allow to update pto with disabled policy' do
      @pto_request.begin_date = Date.today + 10.days
      expect(@pto_request.valid?).to eq(false)
    end

    it 'should not allow to approve pto with disabled policy' do
      @pto_request.status = 1
      expect(@pto_request.valid?).to eq(false)
    end

    it 'should not allow to deny pto with disabled policy' do
      @pto_request.status = 2
      expect(@pto_request.valid?).to eq(false)
    end

    it 'should not allow to cancel pto with disabled policy' do
      @pto_request.status = 3
      expect(@pto_request.valid?).to eq(false)
    end

    it 'should allow to delete pto with disabled policy' do
      @pto_request.assigned_pto_policy.destroy
      @pto_request.destroy
      expect(@pto_request.errors.count).to eq(0)
    end

  end

  describe 'pto balance deduction with overlapping holidays' do
    before do
      @nick = nick
      @pto_policy = @nick.pto_policies.first
      @pto_request = create(:default_pto_request, partial_day_included: false, begin_date: nick.company.time.to_date, end_date: nick.company.time.to_date + 12.days, pto_policy: @pto_policy, user: @nick, status: 1)
    end

    context 'holiday occuring between pto request' do
      before do
        @holiday = create(:holiday, company: @nick.company, multiple_dates: true, begin_date: @pto_request.begin_date + 1.days, end_date: @pto_request.end_date - 2.days)
      end

      it 'should deduct balance effected by holidays' do
        previous_balance = @nick.assigned_pto_policies.first.balance + @nick.assigned_pto_policies.first.carryover_balance
        balance_to_deduct = @pto_request.get_balance_used
        @pto_request.update_column(:balance_deducted, false)
        Pto::DeductBalances.new.perform(company)
        new_balance = @nick.reload.assigned_pto_policies.first.balance + @nick.reload.assigned_pto_policies.first.carryover_balance
        expect(new_balance.round(5)).to eq((previous_balance - balance_to_deduct).round(5))
      end
    end
  end

  describe 'Pto requests on manager delete' do 
    before do
      @nick = nick
      @pto_policy = @nick.pto_policies.first
      @pending_pto_request = create(:default_pto_request, partial_day_included: false, begin_date: nick.company.time.to_date, end_date: nick.company.time.to_date, pto_policy: @pto_policy, user: @nick, status: 0)
      @approved_pto_request = create(:default_pto_request, partial_day_included: false, begin_date: nick.company.time.to_date + 1.days, end_date: nick.company.time.to_date + 1.days, pto_policy: @pto_policy, user: @nick, status: 1)
      @canceled_pto_request = create(:default_pto_request, partial_day_included: false, begin_date: nick.company.time.to_date + 2.days, end_date: nick.company.time.to_date + 2.days, pto_policy: @pto_policy, user: @nick, status: 3)
      @denied_pto_request = create(:default_pto_request, partial_day_included: false, begin_date: nick.company.time.to_date + 3.days, end_date: nick.company.time.to_date + 3.days, pto_policy: @pto_policy, user: @nick, status: 2)
      @nick.manager.destroy!
    end

    it 'should auto deny pending request on manager destroy' do
      expect(@pending_pto_request.reload.status).to eq("denied")
    end

    it 'should not auto deny approved request on manager destroy' do
      expect(@approved_pto_request.reload.status).to eq("approved")
    end

    it 'should not auto deny cancelled request on manager destroy' do
      expect(@canceled_pto_request.reload.status).to eq("cancelled")
    end

    it 'should keep denied request as it is on manager destroy' do
      expect(@denied_pto_request.reload.status).to eq("denied")
    end
  end

  describe 'Pto requests on period change' do 
    let(:sam) {FactoryGirl.create(:user_with_manager_and_policy, :cannot_obtain_negative_balance, email: "can@can.com", personal_email: "zan@zan.com")}
    before do
      @pto_policy = sam.pto_policies.first
      sam.assigned_pto_policies.first.update_column(:balance, 24)
      User.current = sam
    end

    it 'should be a valid pto request and should remain valid after period change' do
      @pto_request = create(:default_pto_request, partial_day_included: false, begin_date: sam.start_date, end_date: sam.start_date, pto_policy: @pto_policy, user: sam, status: 0)
      expect(@pto_request.valid?).to eq(true)
      @pto_policy.update(accrual_renewal_time: 0)
      expect(@pto_request.valid?).to eq(true)
    end
  end

  describe 'Available balance' do 
    before { @date = company.time.to_date}
    context 'unlimited policy' do
      let(:sam) {FactoryGirl.create(:user_with_manager_and_policy, :unlimited_policy, email: "tan@tan.com", personal_email: "dan@dan.com", company: company)}
      
      it 'should allow pto request more than estimated balance' do
        pto = build(:default_pto_request, user: sam, pto_policy: sam.pto_policies.first, begin_date: @date + 40.days, end_date: @date + 40.days, balance_hours: (Pto::PtoEstimateBalance.new(nick.assigned_pto_policies.first, @date + 40.days, sam.company).perform[:estimated_balance] + 20))
        expect(pto.valid?).to eq(true)
      end
    end

    context 'not allowing negative balance' do
      let(:sam) {FactoryGirl.create(:user_with_manager_and_policy, :cannot_obtain_negative_balance, email: "tan@tan.com", personal_email: "dan@dan.com")}
      before do
        @policy = sam.assigned_pto_policies.first
        User.current = sam
      end

      it 'should allow user to make request equal to balance got through estimation' do 
        req = FactoryGirl.create(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 90.days, end_date: sam.start_date + 90.days, pto_policy_id: @policy.pto_policy_id, user: sam, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 90.days, @policy.pto_policy.company).perform)[:estimated_balance])
        expect(req.valid?).to eq(true)
      end

      it 'should not allow user to make request if future requests are affected' do 
        pto = FactoryGirl.create(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 90.days, end_date: sam.start_date + 90.days, pto_policy_id: @policy.pto_policy_id, user: sam, status: 0, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 90.days, @policy.pto_policy.company).perform)[:estimated_balance])
        FactoryGirl.create(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 180.days, end_date: sam.start_date + 180.days, pto_policy_id: @policy.pto_policy_id, user: sam, status: 0, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 180.days, @policy.pto_policy.company).perform)[:estimated_balance] - pto.balance_hours)
        req = FactoryGirl.build(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 89.days, end_date: sam.start_date + 89.days, pto_policy_id: @policy.pto_policy_id, user: sam, status: 0, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 89.days, @policy.pto_policy.company).perform)[:estimated_balance])
        expect(req.valid?).to eq(false)
      end

      it 'should  allow user to make request if future requests are not affected' do 
        pto = FactoryGirl.create(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 90.days, end_date: sam.start_date + 90.days, pto_policy_id: @policy.pto_policy_id, user: sam, status: 0, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 90.days, @policy.pto_policy.company).perform)[:estimated_balance])
        FactoryGirl.create(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 180.days, end_date: sam.start_date + 180.days, pto_policy_id: @policy.pto_policy_id, user: sam, status: 0, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 180.days, @policy.pto_policy.company).perform)[:estimated_balance] - pto.balance_hours)
        req = FactoryGirl.build(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 89.days, end_date: sam.start_date + 89.days, pto_policy_id: @policy.pto_policy_id, user: sam, status: 0, balance_hours: 0)
        expect(req.valid?).to eq(true)
      end

      it 'should allow user to make request equal to balance got through estimation in next periods' do 
        req = FactoryGirl.create(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 400.days, end_date: sam.start_date + 400.days, pto_policy_id: @policy.pto_policy_id, user: sam,  balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 90.days, @policy.pto_policy.company).perform)[:estimated_balance])
        expect(req.valid?).to eq(true)
      end

      it 'should not allow user to make request greater than the balance got through estimation' do 
        req = FactoryGirl.build(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 90.days, end_date: sam.start_date + 90.days, pto_policy_id: @policy.pto_policy_id, user: sam, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 90.days, @policy.pto_policy.company).perform)[:estimated_balance] + 2)
        expect(req.valid?).to eq(false)
      end

      it 'should not allow user to make request equal to estimated balnce for policy having accrual at the end of period on accrual date' do
        @policy.pto_policy.update(allocate_accruals_at: "end")
        req = FactoryGirl.build(:default_pto_request, partial_day_included: false, begin_date: (sam.start_date + 90.days).end_of_week, end_date: (sam.start_date + 90.days).end_of_week, pto_policy_id: @policy.pto_policy_id, user: sam, balance_hours: (Pto::PtoEstimateBalance.new(@policy, (sam.start_date + 90.days).end_of_week, @policy.pto_policy.company).perform)[:estimated_balance] + 2)
        expect(req.valid?).to eq(false)
      end
    end

    context 'allowing negative balance' do
      let(:sam) {FactoryGirl.create(:user_with_manager_and_policy, email: "tan@tan.com", personal_email: "dan@dan.com")}
      before do
        @policy = sam.assigned_pto_policies.first
        User.current = sam
      end

      it 'should allow user to make request equal to balance got through estimation' do 
        req = FactoryGirl.create(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 90.days, end_date: sam.start_date + 90.days, pto_policy_id: @policy.pto_policy_id, user: sam, status: 0, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 90.days, @policy.pto_policy.company).perform)[:estimated_balance])
        expect(req.valid?).to eq(true)
      end

      it 'should allow user to make request equal to balance got through estimation in next periods' do 
        req = FactoryGirl.create(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 400.days, end_date: sam.start_date + 400.days, pto_policy_id: @policy.pto_policy_id, user: sam, status: 0, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 90.days, @policy.pto_policy.company).perform)[:estimated_balance])
        expect(req.valid?).to eq(true)
      end

      it 'should allow user to make request greater than the balance got through estimation' do 
        req = FactoryGirl.build(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 90.days, end_date: sam.start_date + 90.days, pto_policy_id: @policy.pto_policy_id, user: sam, status: 0, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 90.days, @policy.pto_policy.company).perform)[:estimated_balance] + 2)
        expect(req.valid?).to eq(true)
      end

      it 'should not allow user to make request greater than the balance got through estimation + maximum_negative_amount' do 
        req = FactoryGirl.build(:default_pto_request, partial_day_included: false, begin_date: sam.start_date + 90.days, end_date: sam.start_date + 90.days, pto_policy_id: @policy.pto_policy_id, user: sam, balance_hours: (Pto::PtoEstimateBalance.new(@policy, sam.start_date + 90.days, @policy.pto_policy.company).perform)[:estimated_balance] + 2 + sam.pto_policies.first.maximum_negative_amount)
        expect(req.valid?).to eq(false)
      end
    end

  end


  describe '#validations' do
    let(:pto_policy) { create(:default_pto_policy, company: nick.company) }
    context 'pto request ending in next years' do
      let(:pto_request) { build(:default_pto_request, user: nick, pto_policy: pto_policy, begin_date: nick.company.time.to_date, end_date: (nick.company.time + 1.year).to_date)}
      it 'should be valid' do
        expect(pto_request.valid?).to eq(true)
      end
    end
    context 'pto_request starting from previous year' do
      let(:pto_request) { build(:default_pto_request, user: nick, pto_policy: pto_policy, begin_date: (nick.company.time - 1.year).to_date, end_date: nick.company.time.to_date)}
      it 'should be valid' do
        expect(pto_request.valid?).to eq(true)
      end
    end
    context 'pto_request starting and ending in current year' do
      let(:pto_request) { build(:default_pto_request, user: nick, pto_policy: pto_policy, begin_date: nick.company.time.to_date, end_date: nick.company.time.to_date)}
      it 'should be valid' do
        expect(pto_request.valid?).to eq(true)
      end
    end
    context 'maximum increment' do
      let(:sam) {FactoryGirl.create(:user_with_manager_and_policy, :with_maximum_increment, email: "tan@tan.com", personal_email: "dan@dan.com")}
      let(:pto_request) { build(:default_pto_request, user: sam, pto_policy: sam.pto_policies.first, begin_date: nick.company.time.to_date, end_date: nick.company.time.to_date, balance_hours: 16)}
      it 'should be invalid' do
        expect(pto_request.valid?).to eq(false)
      end
    end

    context 'minimum increment' do
      let(:sam) {FactoryGirl.create(:user_with_manager_and_policy, :with_minimum_increment, email: "tan@tan.com", personal_email: "dan@dan.com")}
      let(:pto_request) { build(:default_pto_request, user: sam, pto_policy: sam.pto_policies.first, begin_date: nick.company.time.to_date, end_date: nick.company.time.to_date, balance_hours: 7)}
      it 'should be invalid' do
        expect(pto_request.valid?).to eq(false)
      end
    end
  end

  describe 'Pto requests add back balance for policy with max accrual' do 
    let(:sam) {FactoryGirl.create(:user_with_manager_and_policy, :wih_max_accrual, email:"sample@nick.com", start_date: Date.today - 1.year)}
    before do
      User.current = sam
      @pto_policy = sam.pto_policies.first
      @pto_request = FactoryGirl.create(:default_pto_request, user: sam, pto_policy: @pto_policy, begin_date: sam.company.time.to_date, end_date: sam.company.time.to_date + 1.days, balance_hours: 16)
      sam.assigned_pto_policies.first.update_column(:balance, 16)
    end

    it 'should not allow balance to exceed the max cap on cancel' do
      @pto_request.update(status: 3)
      expect(sam.assigned_pto_policies.first.reload.total_balance <= (@pto_policy.max_accrual_amount * @pto_policy.working_hours)).to eq(true)
    end
    
    it 'should not allow balance to exceed the max cap on deny' do
      @pto_request.update(status: 2)
      expect(sam.assigned_pto_policies.first.reload.total_balance <= (@pto_policy.max_accrual_amount * @pto_policy.working_hours)).to eq(true)
    end

    it 'should not allow balance to exceed the max cap on updating request to less balance' do
      @pto_request.update(end_date: sam.company.time.to_date, balance_hours: 8)
      expect(sam.assigned_pto_policies.first.reload.total_balance <= (@pto_policy.max_accrual_amount * @pto_policy.working_hours)).to eq(true)
    end

    it 'should not allow balance to exceed the max cap on updating request to greater balance' do
      @pto_request.update(end_date: sam.company.time.to_date + 2.days, balance_hours: 24)
      expect(sam.assigned_pto_policies.first.reload.total_balance <= (@pto_policy.max_accrual_amount * @pto_policy.working_hours)).to eq(true)
    end
  end

  describe 'It should not deduct balance twice' do
    before do
      @pto_request = create(:default_pto_request, partial_day_included: false, begin_date: nick.company.time.to_date, end_date: nick.company.time.to_date + 12.days, pto_policy: nick.pto_policies.first, user: nick, status: 1)
    end
    
    it 'shoud have balance_deducted true' do 
      expect(@pto_request.balance_deducted).to eq(true)
    end

    context 'deducting balance again' do
      it 'should not deduct balance' do
        previous_balance = nick.assigned_pto_policies.first.total_balance
        Pto::DeductBalances.new.perform(company)
        expect(nick.assigned_pto_policies.first.reload.total_balance).to eq(previous_balance)
      end
    end
  end

  describe 'Send Email To Respective Role' do
    context 'with manager present' do
      context 'Send Request to Manager for approval' do
        context 'on create' do
          it 'should send email on create' do
            Sidekiq::Testing.inline! do
              expect{FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}.to change{ CompanyEmail.all.count }.by(1)
            end
          end

          it 'should send email to manager' do
            Sidekiq::Testing.inline! do
              FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
              expect(CompanyEmail.order('id DESC').take.to[0]).to eq(nick.manager.email)
            end
          end
        end

        context 'On Update' do
          before do
            @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
          end

          it 'should send email on update Balance hours' do
            Sidekiq::Testing.inline! do
              expect{@pto_request.update(balance_hours: @pto_request.balance_hours + 2)}.to change{ CompanyEmail.all.count }.by(1)
            end
          end


          it 'should send email on update begin_date' do
            Sidekiq::Testing.inline! do
              expect{@pto_request.update(begin_date: @pto_request.begin_date - 3.days)}.to change{ CompanyEmail.all.count }.by(1)
            end
          end

          it 'should send email on update end_date' do
            Sidekiq::Testing.inline! do
              @pto_request.real_end_date_was = @pto_request.get_end_date
              @pto_request.real_end_date = @pto_request.end_date + 3.days
              expect{@pto_request.update(end_date: @pto_request.end_date + 3.days)}.to change{ CompanyEmail.all.count }.by(1)
            end
          end
          
          it 'should send email to manger' do
            Sidekiq::Testing.inline! do
              @pto_request.update(balance_hours: @pto_request.balance_hours + 2)
              expect(CompanyEmail.order('id DESC').take.to[0]).to eq(nick.manager.email)
            end
          end
        end

        context 'Send Approval or Denial Email' do  
          before do
            @pto_request =  FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
          end
          it 'should send email on approval' do
            Sidekiq::Testing.inline! do
              expect{@pto_request.update(status: 1)}.to change{ CompanyEmail.all.count }.by(1) 
            end         
          end
          
          it 'should send email on denial' do
            Sidekiq::Testing.inline! do
              expect{@pto_request.update(status: 2)}.to change{ CompanyEmail.all.count }.by(1)   
            end       
          end   

          it 'should send email to user' do
            Sidekiq::Testing.inline! do
              @pto_request.update(status: 2)
              expect(CompanyEmail.order('id DESC').take.to[0]).to eq(nick.email)
            end
          end    
        end

        context 'Send Cancellation Mail' do
          before do
            @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
          end
          it 'should send email on Cancellation' do
            Sidekiq::Testing.inline! do
              expect{@pto_request.update(status: 3)}.to change{ CompanyEmail.all.count }.by(1)  
            end        
          end

          it 'should send email to manager' do
            Sidekiq::Testing.inline! do
              @pto_request.update(status: 3)
              expect(CompanyEmail.order('id DESC').take.to[0]).to eq(nick.manager.email)
            end
          end
        end
      end

      context 'Send Mails for Auto-Approved Policies' do
        let!(:tim) {FactoryGirl.create(:user_with_manager_and_policy, :auto_approval, email: 'tim@test.com', personal_email: 'tim@personal.com', company: company, start_date: Date.today - 1.year)}
        

        context 'create' do
          it 'should send email on create' do
            Sidekiq::Testing.inline! do
              expect{FactoryGirl.create(:default_pto_request, status: 1, user_id: tim.id, pto_policy_id: tim.pto_policies.first.id)}.to change{ CompanyEmail.all.count }.by(1)
            end
          end
          it 'should send email to manager' do
            Sidekiq::Testing.inline! do
              FactoryGirl.create(:default_pto_request, status: 1, user_id: tim.id, pto_policy_id: tim.pto_policies.first.id)
              expect(CompanyEmail.order('id DESC').take.to[0]).to eq(tim.manager.email)
            end
          end
        end

        context 'On Update' do
          let(:pto_request) {FactoryGirl.create(:default_pto_request, user_id: tim.id, pto_policy_id: tim.pto_policies.first.id)}
          it 'should send email on updating Balance hours' do
            Sidekiq::Testing.inline! do
              expect{pto_request.update(balance_hours: pto_request.balance_hours + 2)}.to change{ CompanyEmail.all.count }.by(1)
            end
          end

          it 'should send email on updating begin_date' do
            Sidekiq::Testing.inline! do
              expect{pto_request.update(begin_date: pto_request.begin_date - 3.days)}.to change{ CompanyEmail.all.count }.by(1)
            end
          end

          it 'should send email on updating end_date' do
            Sidekiq::Testing.inline! do
              pto_request.real_end_date_was = pto_request.get_end_date
              pto_request.real_end_date = pto_request.end_date + 3.days
              expect{pto_request.update(end_date: pto_request.end_date + 3.days)}.to change{ CompanyEmail.all.count }.by(1)
            end
          end

          it 'should send email to manager' do
            Sidekiq::Testing.inline! do
              pto_request.update(begin_date: pto_request.begin_date - 3.days)
              expect(CompanyEmail.order('id DESC').take.to[0]).to eq(tim.manager.email)
            end
          end
          
        end
      end
    end 

    context 'with manager not present' do
      before {nick.update(manager_id: nil)}

      context 'Request to Manager for approval' do
        context 'on create' do
          it 'should not send email on create if only approval chain is manager' do
            Sidekiq::Testing.inline! do
              expect{FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}.to change{ CompanyEmail.all.count }.by(0)
            end
          end
        end

        context 'On Update' do
          before do
            @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
          end

          it 'should not send email on update Balance hours' do
            Sidekiq::Testing.inline! do
              expect{@pto_request.update(balance_hours: @pto_request.balance_hours + 2)}.to change{ CompanyEmail.all.count }.by(0)
            end
          end


          it 'should not send email on update begin_date' do
            Sidekiq::Testing.inline! do
              expect{@pto_request.update(begin_date: @pto_request.begin_date - 3.days)}.to change{ CompanyEmail.all.count }.by(0)
            end
          end

          it 'should not send email on update end_date' do
            Sidekiq::Testing.inline! do
              expect{@pto_request.update(end_date: @pto_request.end_date + 3.days)}.to change{ CompanyEmail.all.count }.by(0)
            end
          end
          
        end

        context 'send Approval or Denial Email' do  
          before do
            @pto_request =  FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
          end
          it 'should send email on approval' do
            expect{@pto_request.update(status: 1)}.to change{ CompanyEmail.all.count }.by(1)
          end
          
          it 'should send email on denial' do
            expect{@pto_request.update(status: 2)}.to change{ CompanyEmail.all.count }.by(1)          
          end   
        end

        context 'Dont send Cancellation Mail' do
          before do
            @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
          end
          it 'should send email on Cancellation' do
            expect{@pto_request.update(status: 3)}.to change{ CompanyEmail.all.count }.by(0)          
          end
        end
      end

      context 'Mails for Auto-Approved Policies' do
        let(:tim) {FactoryGirl.create(:user_with_manager_and_policy, :auto_approval, manager_id: nil, email: 'tim@test.com', personal_email: 'tim@personal.com', company: company, start_date: Date.today - 1.year)}

        context 'create' do
          it 'should not send email on create' do
            expect{FactoryGirl.create(:default_pto_request, status: 1, user_id: tim.id, pto_policy_id: tim.pto_policies.first.id)}.to change{ CompanyEmail.all.count }.by(0)
          end
        end

        context 'On Update' do
          let(:pto_request) {FactoryGirl.create(:default_pto_request, user_id: tim.id, pto_policy_id: tim.pto_policies.first.id)}
          it 'should not send email on updating Balance hours' do
            expect{pto_request.update(balance_hours: pto_request.balance_hours + 2)}.to change{ CompanyEmail.all.count }.by(0)
          end

          it 'should not send email on updating begin_date' do
            expect{pto_request.update(begin_date: pto_request.begin_date - 3.days)}.to change{ CompanyEmail.all.count }.by(0)
          end

          it 'should not send email on updating end_date' do
            expect{pto_request.update(end_date: pto_request.end_date + 3.days)}.to change{ CompanyEmail.all.count }.by(0)
          end
        end
      end
    end   
  end
  
  describe '#send_time_off_custom_alert' do
    before { nick.update(manager_id: nil)}
    context 'time off request alerts' do
      let!(:custom_alert_approved) {FactoryGirl.create(:custom_email_alert, company: company)}
      let!(:custom_alert_create) {FactoryGirl.create(:custom_email_alert_create, company: company)}
      let(:pto_request) {FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id, status: 0)}
      it "should send alert email on create" do
        Sidekiq::Testing.inline! do
          expect {pto_request}.to change { CompanyEmail.all.count }.by(1)
        end
      end

      it "should send alert email on update" do
        pto_request
        Sidekiq::Testing.inline! do
          expect {pto_request.update(status: 1)}.to change { CompanyEmail.all.count }.by(2)
        end
      end
    end

    context 'negatve balance alert' do
      let(:pto_request2) {FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id, status: 0, balance_hours: 16, begin_date: company.time, end_date: company.time)}
      let!(:future_request) {FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id, status: 0, balance_hours: 16, begin_date: company.time + 1.day, end_date: company.time + 1.day)}
      let!(:negative_balance_alert) {create(:negative_balance_alert, company: company)}

      it "should send alert email when balance is negative" do
        Sidekiq::Testing.inline! do
          expect {pto_request2}.to change { CompanyEmail.all.count }.by(1)
        end
      end

      it "should not send alert email when balance is not negative" do
        nick.assigned_pto_policies.first.update(balance: 200)
        Sidekiq::Testing.inline! do
          expect {pto_request2}.to change { CompanyEmail.all.count }.by(0)
        end
      end

      it "should not send alert email when balance is negative and request amount is decreased" do
        pto_request2
        Sidekiq::Testing.inline! do
          expect {pto_request2.update(end_date: company.time + 1.day, balance_hours: 8)}.to change { CompanyEmail.all.count }.by(0)
        end
      end

      it "should send alert email when balance is negative and deducted through job" do
        pto_request2.update(balance_deducted: false)
        pto_request2.pto_policy.update(working_days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
        Sidekiq::Testing.inline! do
          expect {Pto::DeductBalances.new.perform(company)}.to change { CompanyEmail.all.count }.by(1)
        end
      end
    end
  end

  describe '#create_time_off_calendar_event' do
    before do
      company.update_column(:enabled_calendar, true)
    end
    context 'Policy with Manager Approval' do
      let(:pto_request) {FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}

      it "should not create calender event for pending request" do
        expect(pto_request.calendar_event).to eq(nil)
      end
        
      it "should create calender event for request after Manager Approval" do
        pto_request.update(status: 1)
        expect(pto_request.calendar_event).to_not eq(nil)
      end
    end

    context 'Policy with Auto-Approval' do
      let(:tim) {FactoryGirl.create(:user_with_manager_and_policy, :auto_approval, email: 'tim@test.com', personal_email: 'tim@personal.com', company: company, start_date: Date.today - 1.year)}      
      let(:pto_request) {FactoryGirl.create(:default_pto_request, user_id: tim.id, pto_policy_id: tim.pto_policies.first.id, status: 1)}
      
      it 'should create calendar event' do
        expect(pto_request.calendar_event).to_not eq(nil)          
      end

      it 'should delete calendar event if status is changed from approved' do
        pto_request.update(status: 3)
        expect(pto_request.reload.calendar_event ).to eq(nil)
      end
    end
  end

  describe '#setPendingStatusOntimeChange' do
    context 'manager_approval required' do 
      let(:pto_request) {create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}
      before do
        pto_request.update(status: PtoRequest.statuses["approved"])
      end
      it 'should update the approved staus to pendng on updating begin_date/end_date' do
        pto_request.update!(begin_date: pto_request.begin_date + 1.day, end_date: pto_request.end_date + 1.day)
        expect(pto_request.reload.status).to eq("pending")
      end

      it 'should update the approved staus to pendng on updating balance_hours' do
        pto_request.update(balance_hours: 10)
        expect(pto_request.reload.status).to eq("pending")
      end
    end

    context 'manager_approval not required' do 
      before do
        nick.pto_policies.first.update(manager_approval: false)
        @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, status: PtoRequest.statuses["approved"], pto_policy_id: nick.pto_policies.first.id)
      end
      
      it 'should not update the approved staus to pendng on updating begin_date/end_date' do
        @pto_request.update(begin_date: nick.company.time.to_date + 1.day, end_date: nick.company.time.to_date + 1.day)
        expect(@pto_request.reload.status).to_not eq("pending")
      end

      it 'should not update the approved staus to pendng on updating balance_hours' do
        @pto_request.update(balance_hours: 10)
        expect(@pto_request.reload.status).to_not eq("pending")
      end
    end
  end


  describe 'approval_chain' do
    let(:pto_request) {create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}
    
    context 'one level approval chain' do
      it 'should have approval request' do
        expect(pto_request.approval_requests.count).to eq(1)
      end

      it 'should update to approved when request is aproved' do
        pto_request.update(status: "approved")
        expect(pto_request.approval_requests.first.request_state).to eq("approved")
        expect(pto_request.reload.status).to eq("approved")
      end
    end

    context 'no manager' do
      before do
        nick.update(manager_id: nil)
      end
      it 'should have approval request' do
        expect(pto_request.approval_requests.count).to eq(0)
      end

      it 'should approve the request' do
        pto_request.update(status: "approved")
        expect(pto_request.reload.status).to eq("approved")
      end
    end

    context 'multilevel approval chain' do
      before do
        nick.pto_policies.first.approval_chains << FactoryGirl.create(:approval_chain, approval_type: ApprovalChain.approval_types[:permission], approval_ids: ["all"])
      end
      
      it 'should have approval requests' do
        expect(pto_request.approval_requests.count).to eq(2)
      end

      it 'should update  approval reqeusts to approved when request is aproved' do
        pto_request.update(status: "approved")
        expect(pto_request.approval_requests.first.request_state).to eq("approved")
        expect(pto_request.reload.status).to_not eq("approved")
        pto_request.update(status: "approved")
        expect(pto_request.approval_requests.first.request_state).to eq("approved")
        expect(pto_request.reload.status).to eq("approved")
      end
    end

    context 'on deleting approval chain' do
      before do
        nick.pto_policies.first.approval_chains << FactoryGirl.create(:approval_chain, approval_type: ApprovalChain.approval_types[:permission], approval_ids: ["all"])
        pto_request
      end
      
      it 'should have one less approval request' do
        expect(pto_request.approval_requests.count).to eq(2)
        nick.pto_policies.first.approval_chains.first.destroy
        expect(pto_request.approval_requests.count).to eq(1)
      end

      it 'should send email for next approval' do
        Sidekiq::Testing.inline! do
          expect{nick.pto_policies.first.approval_chains.first.destroy}.to change{CompanyEmail.all.count}.by(nick.company.users.count)
        end
      end
    end

    context 'on update' do
      before do
        nick.pto_policies.first.approval_chains << FactoryGirl.create(:approval_chain, approval_type: ApprovalChain.approval_types[:permission], approval_ids: ["all"])
        pto_request
      end
      
      it 'should have updated approval requests' do
        old_approvals = pto_request.approval_requests.pluck(:id)
        pto_request.update(balance_hours: 7)
        expect(pto_request.reload.approval_requests.count).to eq(2)
        expect(pto_request.reload.approval_requests.pluck(:id)).to_not eq(old_approvals)
      end

      it 'should send email for new approval' do
        Sidekiq::Testing.inline! do
          expect{pto_request.update(balance_hours: 7)}.to change{CompanyEmail.all.count}.by(1)
        end
      end

      it 'should set email options for request' do
        pto_request.update(balance_hours: 7)
        expect(pto_request.reload.email_options).to_not eq(nil)
      end
    end
  end

  describe 'create_auto_deny_activity' do
    let(:pto_request) {create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}

    it 'should create_auto_deny_activity' do
      pto_request.create_auto_deny_activity(user_id: nick.id)
      expect(pto_request.activities.present?).to eq(true)
    end
  end

  describe 'create_comment_activity' do
    let(:pto_request) {create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}

    it 'should create_comment_activity' do
      pto_request.create_comment_activity(user_id: nick.id)
      expect(pto_request.activities.present?).to eq(true)
    end
  end

  describe 'create status related activity' do
    let(:pto_request) {create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}

    it 'should create status related activity from pending to approved' do
      pto_request.create_status_related_activity(nick.id, 'approved', 'pending')
      expect(pto_request.activities.first.description).to eq("submitted the request")
      expect(pto_request.activities.last.description).to eq("approved the request")
    end

    it 'should create status related activity from pending to cancelled' do
      pto_request.create_status_related_activity(nick.id, 'cancelled', 'pending')
      expect(pto_request.activities.first.description).to eq("submitted the request")
      expect(pto_request.activities.last.description).to eq("canceled the request")
    end

    it 'should create status related activity from pending to pending' do
      pto_request.create_status_related_activity(nick.id, 'pending', 'pending')
      expect(pto_request.activities.first.description).to eq("submitted the request")
      expect(pto_request.activities.last.description).to eq("modified the request")
    end

    it 'should create status related activity from pending to denied' do
      pto_request.create_status_related_activity(nick.id, 'denied', 'pending')
      expect(pto_request.activities.first.description).to eq("submitted the request")
      expect(pto_request.activities.last.description).to eq("denied the request")
    end
  end

  describe 'check pending pto requests' do
    before {User.current = nick}
    let(:nick) {create(:user_with_manager_and_policy, company: company)}
    let!(:pto_request){ create(:pto_request, pto_policy: nick.pto_policies.first, user: nick,
      partial_day_included: false,  user: nick, begin_date: nick.start_date + 2.days,
      end_date: nick.start_date + 2.days, status: 0) }
    it 'should check pending pto requests that have approval type is manager' do   
      get_pending_pto_requests = PtoRequest.pending_pto_request(ApprovalChain.approval_types[:manager], company, nick.id)
      expect(get_pending_pto_requests&.count).to eq(1)
    end
    it 'should return nil when calling pending_pto_request without company params' do   
      get_pending_pto_requests = PtoRequest.pending_pto_request(ApprovalChain.approval_types[:manager], nil, nick.id)
      expect(get_pending_pto_requests&.count).to eq(nil)
    end
    it 'should return nil when calling pending_pto_request without user_id params' do   
      get_pending_pto_requests = PtoRequest.pending_pto_request(ApprovalChain.approval_types[:manager], company, nil)
      expect(get_pending_pto_requests&.count).to eq(nil)
    end
    it 'should return nil when calling pending_pto_request without approval type params' do   
      get_pending_pto_requests = PtoRequest.pending_pto_request(nil, company, nick.id)
      expect(get_pending_pto_requests&.count).to eq(nil)
    end
  end
end
