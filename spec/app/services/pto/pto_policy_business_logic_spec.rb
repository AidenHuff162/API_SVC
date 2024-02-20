require 'rails_helper'

RSpec.describe Pto::PtoPolicyBusinessLogic do
  let(:company) {create(:company, enabled_time_off: true)}

  describe 'create_pto_policy' do
    before do
      @params = {name: "New Vacation Policy", icon: "icon-heart", for_all_employees: true, policy_type: "vacation", filter_policy_by: "{\"location\":[\"all\"],\"teams\":[\"all\"],\"employee_status\":[\"all\"]}", unlimited_policy: false, accrual_rate_amount: 20, accrual_rate_unit: "hours", rate_acquisition_period: "year", accrual_frequency: "weekly", max_accrual_amount: nil, allocate_accruals_at: "end", start_of_accrual_period: "hire_date", accrual_renewal_time: "1st_of_january", accrual_renewal_date: "2019-01-01", first_accrual_method: "prorated_amount", carry_over_unused_timeoff: true, has_maximum_carry_over_amount: false, can_obtain_negative_balance: true, carry_over_negative_balance: true, manager_approval: false, auto_approval: true, tracking_unit: "hourly_policy", expire_unused_carryover_balance: false, working_hours: 8, half_day_enabled: false, days_to_wait_until_auto_actionable: 7, working_days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]}
    end

    it 'should create pto policy' do 
      expect{Pto::PtoPolicyBusinessLogic.new(@params, company).create_pto_policy}.to change{PtoPolicy.all.count}.by(1)
    end
    
    context 'attributes check' do
      before {Pto::PtoPolicyBusinessLogic.new(@params, company).create_pto_policy}
      
      it 'should have attributes same name as params' do
        expect(PtoPolicy.last.name).to eq(@params[:name])
      end

      it 'should have attributes same icon as params' do
        expect(PtoPolicy.last.icon).to eq(@params[:icon])
      end

      it 'should have attributes same working_hours as params' do
        expect(PtoPolicy.last.working_hours).to eq(@params[:working_hours])
      end
      
      it 'should have attributes same accrual_rate_amount as params' do
        expect(PtoPolicy.last.accrual_rate_amount).to eq(@params[:accrual_rate_amount])
      end
    end

    context 'invalid params' do
      before do
        @params.delete(:name)
        @policy = Pto::PtoPolicyBusinessLogic.new(@params, company).create_pto_policy
      end
      it 'should not create PtoPolicy' do
        expect(PtoPolicy.all.count).to eq(0)
      end

      it 'should return error message' do
        expect(@policy.errors.messages.count).to_not eq(0)
      end
    end

    context 'with tenureships' do
      before {@params.merge!({ "policy_tenureships_attributes" => [{year: 1, amount: 5}]})}
      context 'valid' do
        it 'should create PtoPolicy' do
          expect{Pto::PtoPolicyBusinessLogic.new(@params, company).create_pto_policy}.to change{PtoPolicy.all.count}.by(1)
        end

        it 'should create tenureship' do
          expect{Pto::PtoPolicyBusinessLogic.new(@params, company).create_pto_policy}.to change{PolicyTenureship.all.count}.by(1)
        end
      end

      context 'invalid' do
        before do
          @params["policy_tenureships_attributes"].push({year: 1, amount: 5})
          @policy = Pto::PtoPolicyBusinessLogic.new(@params, company).create_pto_policy
        end

        it 'should not create PtoPolicy' do
          expect(PtoPolicy.all.count).to eq(0)
        end

        it 'should not create tenureship' do
          expect(PolicyTenureship.all.count).to eq(0)
        end

        it 'should return error message' do
          expect(@policy.errors.messages.count).to_not eq(0)
        end
      end
    end
  end

  describe 'update_pto_policy' do
    let!(:pto_policy) {create(:default_pto_policy, company: company)}
    context 'valid params' do
      before do
        @params = {"id" => pto_policy.id, name: "New Vacation Policy", icon: "icon-heart", working_hours: 9}
        Pto::PtoPolicyBusinessLogic.new(@params, company).update_pto_policy
      end

      it 'should update pto policy name' do 
        expect(pto_policy.reload.name).to eq("New Vacation Policy")
      end

      it 'should update pto policy icon' do 
        expect(pto_policy.reload.icon).to eq("icon-heart")
      end

      it 'should update pto policy working_hours' do 
        expect(pto_policy.reload.working_hours).to eq(9)
      end
    end
    
   

    context 'invalid id' do
       before do
        @params = {"id" => nil, name: "New Vacation Policy", icon: "icon-heart", working_hours: 9}
        @policy = Pto::PtoPolicyBusinessLogic.new(@params, company).update_pto_policy
      end

      it 'should not update pto policy name' do 
        expect(pto_policy.reload.name).to_not eq("New Vacation Policy")
      end

      it 'should not update pto policy icon' do 
        expect(pto_policy.reload.icon).to_not eq("icon-heart")
      end

      it 'should not update pto policy working_hours' do 
        expect(pto_policy.reload.working_hours).to_not eq(9)
      end
      
      it 'should return nil' do 
        expect(@policy).to eq(nil)
      end

    end

    context 'invalid params' do
       before do
        @params = {"id" => pto_policy.id, name: "", working_hours: -1}
        @policy = Pto::PtoPolicyBusinessLogic.new(@params, company).update_pto_policy
      end

      it 'should not update pto policy name' do 
        expect(pto_policy.reload.name).to_not eq("")
      end

      it 'should not update pto policy working_hours' do 
        expect(pto_policy.reload.working_hours).to_not eq(-1)
      end

      it 'should have error messages' do 
        expect(@policy.errors.messages.count).to_not eq(0)
      end
    end
    context 'with tenureships' do
      before {@params= { "id"=> pto_policy.id, "policy_tenureships_attributes" => [{year: 1, amount: 5}]}}
      context 'valid' do
        before do
          @policy = Pto::PtoPolicyBusinessLogic.new(@params, company).update_pto_policy
        end
        it 'should update PtoPolicy' do
          expect(pto_policy.reload.policy_tenureships.count).to eq(1)
        end

        it 'should create tenureship' do
          expect(PolicyTenureship.all.count).to eq(1)
        end
      end

      context 'invalid' do
        before do
          @params["policy_tenureships_attributes"].push({year: 1, amount: 5})
          @policy = Pto::PtoPolicyBusinessLogic.new(@params, company).update_pto_policy
        end

        it 'should not update_pto_policy ' do
          expect(pto_policy.policy_tenureships.count).to eq(0)
        end

        it 'should not create tenureship' do
          expect(PolicyTenureship.all.count).to eq(0)
        end

        it 'should return error message' do
          expect(@policy.errors.messages.count).to_not eq(0)
        end
      end
    end
  end

  describe 'enable_disable_policy' do
    let!(:pto_policy) {create(:default_pto_policy, company: company)}
    context 'disable' do
      before do
        @params = { "id"=> pto_policy.id, "is_enabled" => false }
        Pto::PtoPolicyBusinessLogic.new(@params, company).update_pto_policy
      end

      it 'should disable policy' do
        expect(pto_policy.reload.is_enabled).to eq(false)
      end
    end

    context 'enable' do
      before do
        pto_policy.update_column(:is_enabled, false)
        @params = { "id"=> pto_policy.id, "is_enabled" => true }
        Pto::PtoPolicyBusinessLogic.new(@params, company).update_pto_policy
      end

      it 'should disable policy' do
        expect(pto_policy.reload.is_enabled).to eq(true)
      end
    end

    context 'invalid paarms' do
      before do
        @params = { "id"=> nil, "is_enabled" => false }
        Pto::PtoPolicyBusinessLogic.new(@params, company).update_pto_policy
      end

      it 'should not disable policy' do
        expect(pto_policy.reload.is_enabled).to eq(true)
      end
    end
  end

  describe 'upload balance' do
    let(:pto_upload_file) {create(:pto_upload_file)}
    let(:nick) {create(:user_with_manager_and_policy)}
    before { @params = {'file' => {'id' => pto_upload_file.id}, 'creator_id' => nick.id, 'id' => nick.pto_policies.first.id}}
    it 'should upload balance and make adjustment' do
      Date.stub(:strptime) { nick.company.time.to_date - 1.day }
      Pto::PtoPolicyBusinessLogic.new(@params, nick.company).upload_balance
      expect(nick.assigned_pto_policies.first.balance).to eq(2)
      expect(nick.assigned_pto_policies.first.pto_adjustments.count).to eq(1)
    end

    it 'should make adjustment and not upload balance if effective date is of futue' do
      Date.stub(:strptime) { nick.company.time.to_date + 2.day }
      Pto::PtoPolicyBusinessLogic.new(@params, nick.company).upload_balance
      expect(nick.assigned_pto_policies.first.balance).to eq(0)
      expect(nick.assigned_pto_policies.first.pto_adjustments.count).to eq(1)
    end

    it 'should not make adjustment and not upload balance if creator_id is not present' do
      @params = {'file' => {'id' => pto_upload_file.id}, 'creator_id' => nil, 'id' => nick.pto_policies.first.id}
      Date.stub(:strptime) { nick.company.time.to_date + 2.day }
      Pto::PtoPolicyBusinessLogic.new(@params, nick.company).upload_balance
      expect(nick.assigned_pto_policies.first.balance).to eq(0)
      expect(nick.assigned_pto_policies.first.pto_adjustments.count).to eq(0)
    end

    it 'should not make adjustment and not upload balance if policy id is not present' do
      @params = {'file' => {'id' => pto_upload_file.id}, 'creator_id' => nick.id, 'id' => nil}
      Date.stub(:strptime) { nick.company.time.to_date + 2.day }
      Pto::PtoPolicyBusinessLogic.new(@params, nick.company).upload_balance
      expect(nick.assigned_pto_policies.first.balance).to eq(0)
      expect(nick.assigned_pto_policies.first.pto_adjustments.count).to eq(0)
    end

    it 'should make logging if file not present in params' do
      @params = {'creator_id' => nick.id, 'id' => nick.pto_policies.first.id}
      Date.stub(:strptime) { nick.company.time.to_date - 1.day }
      expect{Pto::PtoPolicyBusinessLogic.new(@params, nick.company).upload_balance}.to change{Logging.all.count}.by(1)
      expect(nick.assigned_pto_policies.first.balance).to eq(0)
      expect(nick.assigned_pto_policies.first.pto_adjustments.count).to eq(0)
    end

  end
end
