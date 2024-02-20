require 'rails_helper'

RSpec.describe SendWorkspaceInvitationsJob, type: :job do
  let(:company) { create(:company) }
  let!(:inviter) { create(:user, company: company) }
  let!(:member) { create(:user, company: company) }
  let!(:member1) { create(:user, company: company) }
  let!(:workspace) { create(:workspace, company: company) }
  
  
  describe 'send invitation email' do
    context 'having member' do
      before do
        member.workspaces << workspace
        member1.workspaces << workspace
        inviter.workspaces << workspace
      end

      it 'should send invitation email to memebers other than inviter' do
        expect{SendWorkspaceInvitationsJob.perform_now(workspace.id, inviter.id)}.to change{CompanyEmail.all.count}.by(2)
        expect([member.email, member1.email].include? CompanyEmail.order('id DESC').take.to[0]).to eq(true)
        expect([member.email, member1.email].include? CompanyEmail.order('id DESC').second.to[0]).to eq(true)
      end

      it 'should not send email to inviter' do
        expect{SendWorkspaceInvitationsJob.perform_now(workspace.id, inviter.id)}.to change{CompanyEmail.all.count}.by(2)
        expect(CompanyEmail.order('id DESC').take.to[0]).to_not eq(inviter.email)
        expect(CompanyEmail.order('id DESC').second.to[0]).to_not eq(inviter.email)
      end

      it 'should not send any email if workspace not present' do
        expect{SendWorkspaceInvitationsJob.perform_now(34, inviter.id)}.to change{CompanyEmail.all.count}.by(0)
      end

      it 'should not send any email if inviter not present' do
        expect{SendWorkspaceInvitationsJob.perform_now(workspace.id, 43534)}.to change{CompanyEmail.all.count}.by(0)
      end
    end

    context 'having just inviter as member' do
      before do
        inviter.workspaces << workspace
      end
      
      it 'should not send any email if no other member is present' do
        expect{SendWorkspaceInvitationsJob.perform_now(workspace.id, inviter.id)}.to change{CompanyEmail.all.count}.by(0)
      end
    end

    context 'no member' do
      it 'should not send any email if no member is present' do
        expect{SendWorkspaceInvitationsJob.perform_now(workspace.id, inviter.id)}.to change{CompanyEmail.all.count}.by(0)
      end
    end
  end
end
