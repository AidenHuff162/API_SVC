require 'rails_helper'

RSpec.describe Api::V1::Admin::InvitesController, type: :controller do

  let(:company) { create(:company) }
  let(:company2) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:invite) { create(:invite, user_id: user.id)}
  let(:user1) { create(:user, state: :active, role: 'employee', company: company) }
  let(:user2) { create(:user, state: :active, role: 'admin', company: company2) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe 'Authorization' do
    context 'if user of (different) company' do
      it 'cannot manage invite from different company' do
        ability = Ability.new(user2)
        assert ability.cannot?(:manage, invite)
      end
    end
    context 'if user of same company' do
      it 'can manage invite of same company' do
        ability = Ability.new(user)
        assert ability.can?(:manage, invite)
      end
      it 'cannot manage invite if user is employee' do
        ability = Ability.new(user1)
        assert ability.cannot?(:manage, invite)
      end
    end
    context 'if user is not present' do
      it 'cannot manage invite' do
        ability = Ability.new(nil)
        assert ability.cannot?(:manage, invite)
      end
    end
  end

  describe 'Post #resend invite to user' do
    context 'should resend invitation email' do
      it 'if user and company is present' do
        response = post :resend_invitation_email, params: { user_id: user.id }, format: :json
        json = JSON.parse(response.body)
        expect(json).to eq({"title"=>"Invite resent to #{user.get_invite_email_address}"})
      end
    end
    context 'should not resend invitation email' do
      before do
        allow(controller).to receive(:current_company).and_return(nil)
      end
      it 'if company is not present' do
        response = post :resend_invitation_email, params: { user_id: user.id }, format: :json
        json = JSON.parse(response.body)
        expect(json['errors'][0]['status']).to eq('404')
      end
    end
  end
end
