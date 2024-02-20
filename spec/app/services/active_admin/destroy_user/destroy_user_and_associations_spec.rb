require 'rails_helper'

RSpec.describe ActiveAdmin::DestroyUser::DestroyUserAndAssoications do


  describe 'destroy user' do
    let!(:company) {create(:company)}
    let!(:user) {create(:user_with_manager_and_policy, company: company)}
    let!(:custom_email_alert) {create(:custom_email_alert, company: company, edited_by: user)}
    let!(:profile) {create(:profile, user: user)}
    let!(:managed_user){create(:user, company: company, manager: user)}
    let!(:workstream) {create(:workstream, company: company)}
    let!(:task) {create(:task, workstream: workstream)}
    let!(:task_user_connection) {create(:task_user_connection, user: user, task: task)}
    let!(:pto_balance_audit_log) {create(:pto_balance_audit_log, user: user, assigned_pto_policy: user.assigned_pto_policies.first)}
    let!(:pending_hire) {create(:pending_hire, user: user, company: company)}
    before {company.update(owner: user)}
    
    context 'deleting associations' do
      before do
        @assigned_pto_policy = user.assigned_pto_policies.first
        ActiveAdmin::DestroyUser::DestroyUserAndAssoications.new(user.id).perform
      end

      it "should destroy and nullify the associations" do
        expect(AssignedPtoPolicy.with_deleted.find_by(id: @assigned_pto_policy.id)).to eq(nil)
        expect(custom_email_alert.reload.edited_by).to eq(nil)
        expect(company.reload.owner_id).to eq(nil)
        expect(Profile.with_deleted.find_by(id: profile.id)).to eq(nil)
        expect(managed_user.reload.manager_id).to eq(nil)
        expect(TaskUserConnection.with_deleted.find_by(id: task_user_connection.id)).to eq(nil)
        expect(PtoBalanceAuditLog.with_deleted.find_by(id: pto_balance_audit_log.id)).to eq(nil)
        expect(PendingHire.with_deleted.find_by(id: pending_hire.id)).to eq(nil)
      end

    end

    context 'deleting soft deleted associations' do
      before do
        @assigned_pto_policy = user.assigned_pto_policies.first
        @assigned_pto_policy.update_column(:deleted_at, Time.now)
        custom_email_alert.update_column(:deleted_at, Time.now)
        profile.update_column(:deleted_at, Time.now)
        managed_user.update_column(:deleted_at, Time.now)
        task_user_connection.update_column(:deleted_at, Time.now)
        pto_balance_audit_log.update_column(:deleted_at, Time.now)
        ActiveAdmin::DestroyUser::DestroyUserAndAssoications.new(user.id).perform
      end

      it "should destroy and nullify the associations" do
        expect(AssignedPtoPolicy.with_deleted.find_by(id: @assigned_pto_policy.id)).to eq(nil)
        expect(custom_email_alert.reload.edited_by).to eq(nil)
        expect(company.reload.owner_id).to eq(nil)
        expect(Profile.with_deleted.find_by(id: profile.id)).to eq(nil)
        expect(managed_user.reload.manager_id).to eq(nil)
        expect(TaskUserConnection.with_deleted.find_by(id: task_user_connection.id)).to eq(nil)
        expect(PtoBalanceAuditLog.with_deleted.find_by(id: pto_balance_audit_log.id)).to eq(nil)
        expect(PendingHire.with_deleted.find_by(id: pending_hire.id)).to eq(nil)
      end
    end

    context 'associations without soft deletion' do
      let!(:team) {create(:team, owner: user)} 
      let!(:user_email) {create(:user_email, user: user, email_type: 'welcome_email')} 
      let!(:user_email2) {create(:user_email, user: user, email_type: 'offboarding')} 
      before { ActiveAdmin::DestroyUser::DestroyUserAndAssoications.new(user.id).perform  }

      it 'should destroy and nullify the associations' do
        expect(team.reload.owner_id).to eq(nil)
        expect(UserEmail.find_by(id: user_email.id)).to eq(nil)
        expect(UserEmail.find_by(id: user_email2.id)).to eq(nil)
      end
    end

    context 'other user' do
      let!(:user2) {create(:user_with_manager_and_policy, company: company, email: "slow@slow.com", personal_email: "fast@fast.com")}
      before { ActiveAdmin::DestroyUser::DestroyUserAndAssoications.new(user.id).perform  }

      it 'should not delete the other user and associations' do
        expect(User.find(user2.id)).to eq(user2)
        expect(AssignedPtoPolicy.find(user2.assigned_pto_policies.first.id).present?).to eq(true)
      end
    end
  end
end
