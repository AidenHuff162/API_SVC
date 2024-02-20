require 'rails_helper'

RSpec.describe TimeOff::ActivateUnassignedPolicy, type: :job do
  describe 'activating unassigned policy' do
    let(:company) {FactoryGirl.create(:company, subdomain: 'activate', enabled_time_off: true, time_zone: "UTC")}
    let(:user) {create(:user, company: company)}
    let(:pto_policy) {create(:default_pto_policy, assign_manually: true, company: company)}
    before do
      time = Time.now.utc()
      Time.stub(:now) {time.change(hour: 0)}
    end
    context 'effective_date of today' do
      let!(:unassigned_pto_policy) {create(:unassigned_pto_policy, effective_date: Time.now, user: user, pto_policy: pto_policy)}
      before { TimeOff::ActivateUnassignedPolicy.perform_now }
      
      it 'should activate the policy' do
        expect(user.assigned_pto_policies.count).to eq(1)
      end

      it 'should have assigned policy of same policy' do
        expect(user.assigned_pto_policies.first.pto_policy_id).to eq(pto_policy.id)
      end
      
      it 'should destroy unassigned policy ' do
        expect(unassigned_pto_policy.reload.deleted_at).to_not eq(nil)
      end

      it 'should have balance equals to unassigned policy starting balance ' do
        expect(user.assigned_pto_policies.first.balance).to eq(unassigned_pto_policy.starting_balance)
      end

      it 'should have manually assigned true ' do
        expect(user.assigned_pto_policies.first.manually_assigned).to eq(true)
      end
    end

    context 'effective_date of future' do
      let!(:unassigned_pto_policy) {create(:unassigned_pto_policy, effective_date: Time.now + 3.days, user: user, pto_policy: pto_policy)}
      before { TimeOff::ActivateUnassignedPolicy.perform_now }
      
      it 'should not activate the policy' do
        expect(user.assigned_pto_policies.count).to eq(0)
      end

      it 'should not destroy unassigned policy ' do
        expect(unassigned_pto_policy.reload.deleted_at).to eq(nil)
      end
    end

    context 'company time not equal to midnight' do
      let!(:unassigned_pto_policy) {create(:unassigned_pto_policy, effective_date: Time.now, user: user, pto_policy: pto_policy)}
      before do 
        time = Time.now.utc()
        Time.stub(:now) {time.change(hour: 1)}
        TimeOff::ActivateUnassignedPolicy.perform_now 
      end
      it 'should not activate the policy' do
        expect(user.assigned_pto_policies.count).to eq(0)
      end

      it 'should not destroy unassigned policy ' do
        expect(unassigned_pto_policy.reload.deleted_at).to eq(nil)
      end
    end

    context 'invalid unassigned policy' do
      let!(:unassigned_pto_policy) {create(:unassigned_pto_policy, effective_date: Time.now, user: user, pto_policy: pto_policy)}

      context 'user not present' do
        before do 
          unassigned_pto_policy.update_column(:user_id, nil)
          TimeOff::ActivateUnassignedPolicy.perform_now 
        end
        it 'should not activate the policy' do
          expect(user.assigned_pto_policies.count).to eq(0)
        end

        it 'should not destroy unassigned policy ' do
          expect(unassigned_pto_policy.reload.deleted_at).to eq(nil)
        end
      end

      context 'policy not present' do
        before do 
          unassigned_pto_policy.update_column(:pto_policy_id, nil)
          TimeOff::ActivateUnassignedPolicy.perform_now 
        end
        it 'should not activate the policy' do
          expect(user.assigned_pto_policies.count).to eq(0)
        end

        it 'should not destroy unassigned policy ' do
          expect(unassigned_pto_policy.reload.deleted_at).to eq(nil)
        end
      end
    end


    context 'unassigned policies of different companies' do
      let!(:unassigned_pto_policy) {create(:unassigned_pto_policy, effective_date: Time.now, user: user, pto_policy: pto_policy)}
      subject(:company2) {FactoryGirl.create(:company, enabled_time_off: true, time_zone: "UTC")}
      let(:user2) {create(:user, company: company2)}
      let(:pto_policy2) {create(:default_pto_policy, assign_manually: true, company: company2)}
      let!(:unassigned_pto_policy2) {create(:unassigned_pto_policy, effective_date: Time.now, user: user2, pto_policy: pto_policy2)}
      
      before { TimeOff::ActivateUnassignedPolicy.perform_now }

      context 'company1' do
        it 'should activate the policy' do
          expect(user.assigned_pto_policies.count).to eq(1)
        end

        it 'should have assigned policy of same policy' do
          expect(user.assigned_pto_policies.first.pto_policy_id).to eq(pto_policy.id)
        end
        
        it 'should destroy unassigned policy ' do
          expect(unassigned_pto_policy.reload.deleted_at).to_not eq(nil)
        end

        it 'should have balance equals to unassigned policy starting balance ' do
          expect(user.assigned_pto_policies.first.balance).to eq(unassigned_pto_policy.starting_balance)
        end

        it 'should have manually assigned true ' do
          expect(user.assigned_pto_policies.first.manually_assigned).to eq(true)
        end
      end

      context 'company2' do
        it 'should activate the policy' do
          expect(user2.assigned_pto_policies.count).to eq(1)
        end

        it 'should have assigned policy of same policy' do
          expect(user2.assigned_pto_policies.first.pto_policy_id).to eq(pto_policy2.id)
        end
        
        it 'should destroy unassigned policy ' do
          expect(unassigned_pto_policy2.reload.deleted_at).to_not eq(nil)
        end

        it 'should have balance equals to unassigned policy starting balance ' do
          expect(user2.assigned_pto_policies.first.balance).to eq(unassigned_pto_policy2.starting_balance)
        end

        it 'should have manually assigned true ' do
          expect(user2.assigned_pto_policies.first.manually_assigned).to eq(true)
        end
      end
    end    
  end

end
