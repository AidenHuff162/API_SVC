require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe PtoPolicy, type: :model do

  let(:company) { create(:company, subdomain: 'rocketspace', enabled_calendar: true) }
  
  describe 'associations' do
    it { is_expected.to have_many(:approval_chains)}
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:policy_type) }
    it { should validate_presence_of(:icon) }
    it { should validate_inclusion_of(:for_all_employees).in?([true, false]) }
    it { should validate_inclusion_of(:has_maximum_increment).in?([true, false]) }
    it { should validate_inclusion_of(:has_minimum_increment).in?([true, false]) }
    it { should validate_presence_of(:working_days) }
    it { should validate_numericality_of(:days_to_wait_until_auto_actionable)}
    
    context 'limited policy' do 
      it { should validate_presence_of(:accrual_rate_amount) }
      it { should validate_presence_of(:accrual_rate_unit) }
      it { should validate_presence_of(:rate_acquisition_period) }
      it { should validate_presence_of(:accrual_frequency) }
      it { should validate_presence_of(:accrual_frequency) }
      it { should validate_presence_of(:start_of_accrual_period) }
      it { should validate_presence_of(:accrual_renewal_time) }
      it { should validate_presence_of(:tracking_unit) }
      it { should validate_presence_of(:first_accrual_method) }
      it { should validate_presence_of(:accrual_renewal_date) }
      it { should_not validate_presence_of(:unlimited_type_title) }
    end

    context 'unlimited policy' do 
      before { subject.unlimited_policy = true }
      it { should_not validate_presence_of(:accrual_rate_amount) }
      it { should_not validate_presence_of(:accrual_rate_unit) }
      it { should_not validate_presence_of(:rate_acquisition_period) }
      it { should_not validate_presence_of(:accrual_frequency) }
      it { should_not validate_presence_of(:accrual_frequency) }
      it { should_not validate_presence_of(:start_of_accrual_period) }
      it { should_not validate_presence_of(:accrual_renewal_time) }
      it { should_not validate_presence_of(:tracking_unit) }
      it { should_not validate_presence_of(:first_accrual_method) }
      it { should_not validate_presence_of(:accrual_renewal_date) }
      it { should validate_presence_of(:unlimited_type_title) }
    end

    context 'increment check' do
      before do
        subject.has_minimum_increment = true 
        subject.has_maximum_increment = true 
      end
      it { should validate_numericality_of(:maximum_increment_amount)}
      it { should validate_numericality_of(:minimum_increment_amount)}
    end

    context 'can_obtain_negative_balance' do
      before { subject.can_obtain_negative_balance = true }
      it { should validate_numericality_of(:maximum_negative_amount) }
    end
    
    context 'with max_accrual_amount' do
      before { subject.has_max_accrual_amount = true }
      it { should validate_presence_of(:max_accrual_amount) }
      it { should validate_numericality_of(:max_accrual_amount) }
    end
    
    context 'without max_accrual_amount' do
      it { should_not validate_presence_of(:max_accrual_amount) }
      it { should_not validate_numericality_of(:max_accrual_amount) }
    end
    
    context 'with custom date' do
      before { subject.start_of_accrual_period = 'custom_start_date'}
      it { should validate_presence_of(:accrual_period_start_date) }
      it { should validate_numericality_of(:accrual_period_start_date) }
    end

    context 'without custom date' do
      it { should_not validate_presence_of(:accrual_period_start_date) }
      it { should_not validate_numericality_of(:accrual_period_start_date) }
    end

    context 'with carryover' do
      before do 
        subject.carry_over_unused_timeoff = true 
        subject.has_maximum_carry_over_amount = true
      end
      it { should validate_presence_of(:maximum_carry_over_amount) }
      it { should validate_numericality_of(:maximum_carry_over_amount) }
    end

    context 'without carryover' do
      it { should_not validate_presence_of(:maximum_carry_over_amount) }
      it { should_not validate_numericality_of(:maximum_carry_over_amount) }
    end
    
    
    context 'max_accrual_amount' do
      it "should not allow max accrual amount negative" do 
        pto_policy = FactoryGirl.build(:default_pto_policy, company: company, max_accrual_amount: -1)
        expect(pto_policy.valid?).to eq(false)
      end
    end
  end
  
  describe 'after create' do
    context 'with assign_manually true' do
      it 'is not assigned to anyone' do
        Sidekiq::Testing.inline! do
          expect(create(:default_pto_policy, company: company, assign_manually: true).users.size).to eq(0)
        end
      end
    end

    context 'set default filters' do 
      let(:policy) {create(:default_pto_policy, company: company)}
      it 'should have default filter to all' do
        expect(policy.filter_policy_by).to eq({"teams"=>["all"], "location"=>["all"], "employee_status"=>["all"]})
      end
    end
  end

  describe 'after update' do
    let!(:sarah) { create(:sarah, company: company, start_date: Date.today - 1.year ) }
    
    before do
      Sidekiq::Testing.inline! do
        @policy =  FactoryGirl.create(:default_pto_policy, company: company)
      end
      User.current = sarah
    end

    context 'policy disabled' do 

      it 'should unassign from all users on disabling' do
        Sidekiq::Testing.inline! do
          @policy.update(is_enabled: false)
          expect(@policy.assigned_pto_policies.count).to eq(0)
        end
      end
    end

    context 'policy type changed' do 
      let(:pto_request) {create(:default_pto_request, status: 1, user_id: sarah.id, pto_policy_id: @policy.id)}

      it 'should update calendar event of pto request' do
        Sidekiq::Testing.inline! do
          @policy.update(policy_type: 2)
          expect(pto_request.calendar_event.event_type).to eq("time_off_"+@policy.policy_type)
        end
      end
    end
  end

  describe 'validations' do
    context 'for unlimited policy' do
      before { allow(subject).to receive(:unlimited_policy).and_return(true) }
      it { is_expected.to validate_presence_of(:unlimited_type_title) }
    end
    context 'for limited policy' do
      before { allow(subject).to receive(:unlimited_policy).and_return(false) }
      it { is_expected.not_to validate_presence_of(:unlimited_type_title) }
    end
    it { is_expected.to validate_length_of(:unlimited_type_title).is_at_most(20) }

    context 'updating eligibility fields' do
      let(:pto_policy) {create(:default_pto_policy, company: company)}

      it 'should be invalid if for_all_employees is updated' do
        pto_policy.for_all_employees = false
        expect(pto_policy.valid?).to eq(false)
      end

      it 'should be invalid if assign_manually is updated' do
        pto_policy.assign_manually = true
        expect(pto_policy.valid?).to eq(false)
      end
    end
    context 'for manager approval required' do
      it 'should be valid if manager_approval ' do
        pto_policy = build(:default_pto_policy, manager_approval: false, auto_approval: nil)
        expect(pto_policy.valid?).to eq(true)
      end
      it 'should be valid if auto approval options are provided' do
        pto_policy = build(:default_pto_policy, days_to_wait_until_auto_actionable: 7, auto_approval: true)
        expect(pto_policy.valid?).to eq(true)
      end
    
      it 'should be invalid if auto_approval is nil ' do
        pto_policy = build(:default_pto_policy, days_to_wait_until_auto_actionable: 5, auto_approval: nil)
        expect(pto_policy.valid?).to eq(false)
      end
      it 'should be invalid if days_to_wait_until_auto_actionable is nil' do
        pto_policy = build(:default_pto_policy, days_to_wait_until_auto_actionable: nil, auto_approval: false)
        expect(pto_policy.valid?).to eq(false)
      end
      it { should validate_numericality_of(:days_to_wait_until_auto_actionable) }
    end
  end

  describe 'Change in policy filters' do
    let!(:pto_policy) { create(:default_pto_policy, :policy_for_some_employees, company: company)  }

    context 'schedules' do

      it 'job for reassigning policy to new set of users' do
        Sidekiq::Testing.fake!
        new_filters = {"teams": [1, 3, 4, 5], "location": ["all"], "employee_status": ["all"]}
        expect {
          pto_policy.update_attribute(:filter_policy_by, new_filters)
        }.to change(TimeOff::ReassignPolicyOnFilterChangeJob.jobs, :size).by(1)
      end

    end

    context 'assign policies' do
      let!(:sarah) { create(:sarah, :with_location_and_team, company: company, start_date: Date.today - 1.year) }
      let!(:peter) { create(:peter, :with_location_and_team, company: company, start_date: Date.today - 1.year) }

      it 'to users matching the new policies criteria' do
        pto_policy.update_column(:filter_policy_by, {"teams": [sarah.team_id], "location": [sarah.location_id], "employee_status": ["all"]})
        Sidekiq::Testing.inline! {TimeOff::ReassignPolicyOnFilterChangeJob.perform_async(pto_policy.id)}
        expect(sarah.assigned_pto_policies.size).to eq(1)
        expect(peter.assigned_pto_policies.size).to eq(0)
      end

      it 'to all users if all filters are selected to all' do
        pto_policy.update_column(:filter_policy_by, {"teams": ["all"], "location": ["all"], "employee_status": ["all"]})
        Sidekiq::Testing.inline! {TimeOff::ReassignPolicyOnFilterChangeJob.perform_async(pto_policy.id)}
        expect(sarah.assigned_pto_policies.size).to eq(1)
        expect(peter.assigned_pto_policies.size).to eq(1)
      end

    end

    context 'unassign policy' do
      let!(:nick) { create(:user_with_manager_and_policy) }

      it 'from users not having matching filters' do
        pto_policy = nick.pto_policies.first
        cf = pto_policy.company.custom_fields.where(field_type: 13).take
        option_id = cf.custom_field_options.find_by(option: "Full Time")&.id
        pto_policy.update_columns(filter_policy_by: {"teams": [1, 3, 4, 5], "location": [2], "employee_status": [option_id]}, for_all_employees: false)
        Sidekiq::Testing.inline! {TimeOff::ReassignPolicyOnFilterChangeJob.perform_async(pto_policy.id)}
        expect(nick.assigned_pto_policies.size).to eq(0)
      end
    end

    context 'restores' do
      let!(:nick) { create(:user_with_deleted_assigned_pto_policy) }
      it 'deleted assigned_pto_policy if falls in new filters' do
        assigned_policy = nick.assigned_pto_policies.with_deleted.first
        pto_policy = PtoPolicy.find(assigned_policy.pto_policy_id)
        pto_policy.update_column(:filter_policy_by, {"teams": [nick.team_id], "location": [nick.location_id], "employee_status": ["all"]})
        Sidekiq::Testing.inline! {TimeOff::ReassignPolicyOnFilterChangeJob.perform_async(pto_policy.id)}
        expect(nick.assigned_pto_policies.size).to eq(1)
        expect(nick.assigned_pto_policies.first.id).to eq(assigned_policy.id)
      end

    end

    context 'does not restore policies' do
      let!(:nick) { create(:user_with_deleted_assigned_pto_policy, company: company) }

      it 'belonging to deleted users' do
        assigned_policy = nick.assigned_pto_policies.with_deleted.first
        pto_policy = PtoPolicy.find(assigned_policy.pto_policy_id)
        pto_policy.update_column(:filter_policy_by, {"teams": [nick.team_id], "location": [nick.location_id], "employee_status": ["all"]})
        nick.update_column(:deleted_at, Date.today)
        Sidekiq::Testing.inline! {TimeOff::ReassignPolicyOnFilterChangeJob.perform_async(pto_policy.id)}
        expect(nick.assigned_pto_policies.size).to eq(0)
      end
    end
  end

  describe 'Change in policy type' do
    subject(:tim) {FactoryGirl.create(:user_with_manager_and_policy, company: company, start_date: Date.today - 1.year)}

    before do
      @pto_policy = tim.pto_policies.first
      User.current = tim
      @pto_request = FactoryGirl.create(:default_pto_request, status: 1, user_id: tim.id, pto_policy_id: @pto_policy.id)
    end
    
    it 'Calendar event has same type as Policy' do
      expect(@pto_request.calendar_event.event_type).to  eq("time_off_#{@pto_policy.policy_type}")
    end

    it 'should have same type as policy on change' do 
      @pto_policy.update_column(:policy_type, 4)
      Sidekiq::Testing.inline! {TimeOff::UpdatePtoCalendarEvents.perform_async({"policy" => @pto_policy.id})}
      expect(@pto_request.reload.calendar_event.event_type).to  eq("time_off_#{@pto_policy.policy_type}")
    end
    context 'default hours for policy' do
      it 'should not allow policy with working hours 0 or less' do
        pto_policy = FactoryGirl.build(:default_pto_policy, working_hours: -1)
        expect(pto_policy.valid?).to eq(false)
      end
      it 'should not allow policy without working days' do
        pto_policy = FactoryGirl.build(:default_pto_policy, working_days: nil)
        expect(pto_policy.valid?).to eq(false)
      end
    end
    context 'for policy which was manually assigned' do

      before do
        @user = create(:user_manual_assigned_policy_factory, email: 'nicknewton@mail.com', personal_email: 'nicktest@mail.com', company: company)
        @pto_policy = @user.pto_policies.first
        @location = create(:location)
        @team = create(:team)
      end

      it 'should not unassign that policy if filters are not matching' do
        Sidekiq::Testing.inline! do
          @pto_policy.filter_policy_by = {"teams": [@team.id], "location": [@location.id], "employee_status": ["all"]}
          @pto_policy.save
          expect(@user.pto_policies.size).to eq(1)
          expect(@user.pto_policies.first.id).to eq(@pto_policy.id)
        end
      end 

    end

    context 'for policy which was not manually assigned' do

      before do
        @user = create(:user_manual_assigned_policy_factory, :not_assigned_manually, email: 'nicknewton@mail.com', personal_email: 'nicktest@mail.com', company: company)
        @pto_policy = @user.pto_policies.first
        @location = create(:location)
        @team = create(:team)
      end

      it 'should unassign that policy if filters are not matching' do
        Sidekiq::Testing.inline! do
          @pto_policy.filter_policy_by = {"teams": [@team.id], "location": [@location.id], "employee_status": ["all"]}
          @pto_policy.save
          expect(@user.reload.pto_policies.size).to eq(0)
        end
      end

    end

    context 'enabling disabling manually_assigned pto_policy' do

      it 'should unassign manually_assigned policy on disabling' do
        user = create(:user_manual_assigned_policy_factory, email: 'nicknewton@mail.com', personal_email: 'nicktest@mail.com', company: company)
        pto_policy = user.pto_policies.first
        pto_policy.is_enabled = false
        Sidekiq::Testing.inline! do
          pto_policy.save
          expect(user.reload.pto_policies.size).to eq(0)
          expect(user.reload.assigned_pto_policies.with_deleted.first.deleted_at).to_not  eq(nil)
        end
      end

      it 'should assign manually_assigned policy on enabling back' do
        Sidekiq::Testing.inline! do
          user = create(:user_with_disabled_manually_assigned_pto_policy, company: company)
          pto_policy = user.assigned_pto_policies.with_deleted.first.pto_policy
          pto_policy.is_enabled = true
          pto_policy.save
          expect(user.reload.assigned_pto_policies.size).to eq(1)
          expect(user.reload.assigned_pto_policies.first.deleted_at).to eq(nil)
          expect(user.reload.assigned_pto_policies.first.pto_policy_id).to eq(pto_policy.id)
        end
      end

    end

    context 'enabling disabling will restore the old assigned policy' do

      before do
        @user = FactoryGirl.create(:user_with_manager_and_policy, email: 'nicknewton@mail.com', personal_email: 'nicktest@mail.com', company: company)
        @assigned_policy = @user.assigned_pto_policies.first
        @policy = @assigned_policy.pto_policy
        Sidekiq::Testing.inline! do
          @policy.update(is_enabled: false)
        end
      end

      it "should have assigned_policy deleted on disabling" do
        expect(@assigned_policy.reload.deleted_at).not_to eq(nil)
      end

      it 'should restore the same policy on enabling' do
        Sidekiq::Testing.inline! do
          @policy.update(is_enabled: true)
          expect(@assigned_policy.reload.deleted_at).to eq(nil)
        end
      end
    end

    context 'enabling disabling will restore the old manually assigned_policy' do

      before do
        @user = FactoryGirl.create(:user_manual_assigned_policy_factory, email: 'nicknewton@mail.com', personal_email: 'nicktest@mail.com', company: company)
        @assigned_policy = @user.assigned_pto_policies.first
        @policy = @assigned_policy.pto_policy
        Sidekiq::Testing.inline! do
          @policy.update(is_enabled: false)
        end
      end

      it "should have assigned_policy deleted on diabling" do
        expect(@assigned_policy.reload.deleted_at).not_to eq(nil)
        expect(@assigned_policy.reload.manually_assigned).to eq(true)
      end

      it 'should restore the same policy on enabling' do
        Sidekiq::Testing.inline! do
          @policy.update(is_enabled: true)
          expect(@assigned_policy.reload.deleted_at).to eq(nil)
          expect(@assigned_policy.reload.manually_assigned).to eq(true)
        end
      end
    end

  end

  describe 'enabling' do
    let(:pto_policy) {create(:default_pto_policy, company: company, for_all_employees: false ,assign_manually: true, is_enabled: false)}
    let(:nick) {create(:nick, company: company) }
    let(:tim) { create(:tim, company: company, ) }
    let!(:assigned_policy) {create(:assigned_pto_policy, pto_policy: pto_policy, user: nick, manually_assigned: true, deleted_at: company.time.to_date)}
    let!(:auto_assigned_policy) {create(:assigned_pto_policy, pto_policy: pto_policy, user: tim, manually_assigned: false, deleted_at: company.time.to_date)}

    context 'policy with assign_manually true' do
      it 'reassigns to users it was assigned manually' do
        Sidekiq::Testing.inline! do
          pto_policy.update_attribute(:is_enabled, true)
          expect(nick.reload.assigned_pto_policies.size).to eq(1)
        end
      end
      it 'reassigns the same policy to users' do
        Sidekiq::Testing.inline! do
          pto_policy.update_attribute(:is_enabled, true)
          expect(nick.reload.assigned_pto_policies.first.pto_policy_id).to eq(pto_policy.id)
        end
      end
      it 'does not reassigns auto assigned policy' do
        Sidekiq::Testing.inline! do
          pto_policy.update_attribute(:is_enabled, true)
          expect(tim.reload.assigned_pto_policies.size).to eq(0)
        end
      end
    end
  end

  describe 'On policy delete' do
    let(:tim) {FactoryGirl.create(:user_with_manager_and_policy, company: company, start_date: Date.today - 1.year)}
    let(:sarah) {FactoryGirl.create(:sarah, company: company)}

    before do
      @pto_policy = tim.pto_policies.first
      User.current = sarah
      @pto_request = FactoryGirl.create(:default_pto_request, status: 1, user_id: tim.id, pto_policy_id: @pto_policy.id)
      @assigned_policy = @pto_request.assigned_pto_policy
      @pto_adjustment = FactoryGirl.create(:pto_adjustment, hours: 8, creator: sarah, assigned_pto_policy: @assigned_policy)
      @audit_logs = @assigned_policy.pto_balance_audit_logs
      @calendar_event = @pto_request.calendar_event
      @pto_policy.destroy
    end
    
    it 'should have deleted pto_request' do
      expect(@pto_request.reload.deleted_at).not_to eq(nil)
    end
    it 'should have deleted assigned_policy' do
      expect(@assigned_policy.reload.deleted_at).not_to eq(nil)
    end
    it 'should have deleted audit_logs' do
      expect(@audit_logs.reload.pluck(:deleted_at).include?(nil)).to eq(false)
    end
    it 'should have deleted calendar_event' do
      expect(@calendar_event.reload.deleted_at).not_to eq(nil)
    end
    it 'should have deleted pto_adjustment' do
      expect(@pto_adjustment.reload.deleted_at).not_to eq(nil)
    end
  end

  describe 'enable disable policy' do

    before do
      @nick = create(:user_with_pto_policy_for_some_employees_factory, :with_location, company: company)
    end
        
    context 'on disabling' do
      before do
        @pto_policy = @nick.pto_policies.first
      end

      it 'deletes assigned policies from respective users' do
        Sidekiq::Testing.inline! do
          @pto_policy.is_enabled = false
          @pto_policy.save!
          expect(@nick.reload.assigned_pto_policies.size).to eq(0)
          expect(@nick.deleted_at).to eq(nil)
        end
      end

    end

    context 'on enabling' do
      before do
        @pto_policy = @nick.pto_policies.first
        @pto_policy.is_enabled = false
        @pto_policy.save!
      end

      it 'should assign policy to user' do
        Sidekiq::Testing.inline! do
          @pto_policy.is_enabled = true
          @pto_policy.save!
          expect(@nick.reload.assigned_pto_policies.size).to eq(1)
          expect(@nick.reload.assigned_pto_policies.first.deleted_at).to eq(nil)
          expect(@nick.reload.assigned_pto_policies.first.pto_policy_id).to eq(@pto_policy.id)
          expect(@nick.reload.deleted_at).to eq(nil)
        end
      end
    end

    context 'on enabling policy for specific employees' do
      before do
        @pto_policy = @nick.pto_policies.first
        @pto_policy.filter_policy_by = {"teams"=>["all"], "location"=>[@nick.location_id], "employee_status"=>["all"]}   
        @pto_policy.for_all_employees = false
        @pto_policy.is_enabled = false
        @pto_policy.save!
      end

      it 'should assign to employees having matching filters' do
        Sidekiq::Testing.inline! do
          @pto_policy.is_enabled = true
          @pto_policy.save!
          expect(@nick.reload.assigned_pto_policies.size).to eq(1)
          expect(@nick.reload.assigned_pto_policies.first.deleted_at).to eq(nil)
          expect(@nick.reload.assigned_pto_policies.first.pto_policy_id).to eq(@pto_policy.id)
          expect(@nick.reload.deleted_at).to eq(nil)
          expect(@nick.reload.pto_policies.first.filter_policy_by["location"].first).to eq(@nick.location_id)
        end
      end
    end

    context 'on changing filter_policy_by before enabling policy' do
      before do
        @pto_policy = @nick.pto_policies.first
        @pto_policy.filter_policy_by = {"teams"=>["all"], "location"=>[2], "employee_status"=>["all"]} 
        @pto_policy.for_all_employees = false
        @pto_policy.is_enabled = false
        @pto_policy.save!  
      end

      it 'should not assign to employees not having matching fitlers' do
        Sidekiq::Testing.inline! do
          @pto_policy.is_enabled = true
          @pto_policy.save!
          expect(@nick.reload.assigned_pto_policies.size).to eq(0)
        end
      end
    end

    context 'Update assigned_pto_policies' do 
      before do
        Sidekiq::Testing.inline! do
          @policy = FactoryGirl.create(:default_pto_policy, company: company, is_enabled: false)
          @policy.update(is_enabled: true)
        end
      end
      context 'update start_of_accrual_period and first_accrual_happening_date' do
        before do
          @start_of_accrual_period = @policy.assigned_pto_policies.first.start_of_accrual_period
          @first_accrual_happening_date = @policy.assigned_pto_policies.first.first_accrual_happening_date
           @policy.assigned_pto_policies.first.user.update_column(:start_date, company.time.to_date - 2.days)
          @policy.update(accrual_frequency: 5, allocate_accruals_at: 1)
        end
        
        it 'should update start_of_accrual_period' do
          expect(@start_of_accrual_period).to_not eq(@policy.assigned_pto_policies.first.start_of_accrual_period)
        end

        it 'should update first_accrual_happening_date' do
          expect(@first_accrual_happening_date).to_not eq(@policy.assigned_pto_policies.first.first_accrual_happening_date)
        end
      end
    end
  
  end

  describe 'helper methods' do
    context 'get_unlimited_policy_title' do
      let(:pto_policy) {create(:default_pto_policy, unlimited_policy: true)}
      it 'should return the unlimited' do
        expect(pto_policy.get_unlimited_policy_title).to eq("Unlimited")
      end

      it 'should return the unlimited title' do
        pto_policy.update(unlimited_type_title: "Hye")
        expect(pto_policy.get_unlimited_policy_title).to eq("Hye")
      end
    end

    context 'balance_factor' do
      let(:pto_policy) {create(:default_pto_policy)}
      it 'should return the balance_factor 1' do
        pto_policy.update(tracking_unit: PtoPolicy.tracking_units["hourly_policy"])
        expect(pto_policy.balance_factor).to eq(1)
      end

      it 'should return the balance factor equal to working_hours' do
        expect(pto_policy.balance_factor).to eq(pto_policy.working_hours)
      end
    end
  end
end
