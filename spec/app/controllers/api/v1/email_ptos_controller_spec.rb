require 'rails_helper'

RSpec.describe Api::V1::EmailPtosController, type: :controller do
  subject(:nick) {FactoryGirl.create(:user_with_manager_and_policy, start_date: Date.today - 1.year)}
  subject(:user) {FactoryGirl.create(:user, company: nick.company)}

  before do
    allow(controller).to receive(:current_company).and_return(nick.company)
    User.current = nick
    user.set_hash_id
  end

  describe "aprov/deny from email" do
    it "should approve pto request without legacy parameter" do
      pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      get :approve, params: { id: pto_request.id, user_id: user.hash_id }, format: :json
      pto_request.reload
      expect(pto_request.status).to eq("approved")
      
      expect(response.status).to eq(302)
      expect(response.location).to eq("http://#{nick.company.app_domain}/#/pto_comment/#{pto_request.hash_id}?user_id=#{user.hash_id}&approve=1")
    end

    it "should approve pto request with legacy parameter" do
      pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      get :approve, params: { id: pto_request.id, user_id: user.hash_id, lagacy: false}, format: :json
      pto_request.reload
      expect(pto_request.status).to eq("approved")
      
      expect(response.status).to eq(302)
      expect(response.location).to eq("http://#{nick.company.app_domain}/#/pto_comment/#{pto_request.hash_id}?user_id=#{user.hash_id}&approve=1")
    end

    it "should deny pto request without legacy parameter" do
      pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      get :deny, params: { id: pto_request.id, user_id: user.hash_id }, format: :json
      pto_request.reload
      expect(pto_request.status).to eq("denied")
      expect(response.status).to eq(302)
      expect(response.location).to eq("http://#{nick.company.app_domain}/#/pto_comment/#{pto_request.hash_id}?user_id=#{user.hash_id}&approve=0")
    end

    it "should deny pto request with legacy parameter" do
      pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      get :deny, params: { id: pto_request.id, user_id: user.hash_id, lagacy: false}, format: :json
      pto_request.reload
      expect(pto_request.status).to eq("denied")
      expect(response.status).to eq(302)
      expect(response.location).to eq("http://#{nick.company.app_domain}/#/pto_comment/#{pto_request.hash_id}?user_id=#{user.hash_id}&approve=0")
    end

    it "should approve pto request without hash id and without legacy parameter" do
      pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      get :approve, params: { id: pto_request.id, user_id: nil }, format: :json
      pto_request.reload
      expect(pto_request.status).to eq("approved")
      expect(response.status).to eq(302)
      expect(response.location).to eq("http://#{nick.company.app_domain}/#/pto_comment/#{pto_request.hash_id}?user_id=#{nick.manager.reload.hash_id}&approve=1")
    end

    it "should approve pto request without hash id and with legacy parameter" do
      pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      get :approve, params: { id: pto_request.id, user_id: nil, lagacy: false }, format: :json
      pto_request.reload
      expect(pto_request.status).to eq("approved")
      expect(response.status).to eq(302)
      expect(response.location).to eq("http://#{nick.company.app_domain}/#/pto_comment/#{pto_request.hash_id}?user_id=#{nick.manager.reload.hash_id}&approve=1")
    end
  end

  describe "already approved/denied request" do
    it "should return the control back if approving already approved request" do
      pto_request = request_before_updation = FactoryGirl.create(:default_pto_request, :approved_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      get :approve, params: { id: pto_request.id, user_id: user.id }, format: :json
      pto_request.reload
      expect(pto_request).to eq(request_before_updation)
    end

    it "should return the control back if approving already denied request" do
      pto_request = request_before_updation = FactoryGirl.create(:default_pto_request, :denied_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      get :approve, params: { id: pto_request.id, user_id: user.id }, format: :json
      pto_request.reload
      expect(pto_request).to eq(request_before_updation)
    end

    it "should return the control back if denying already approved request" do
      pto_request = request_before_updation = FactoryGirl.create(:default_pto_request, :approved_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      get :deny, params: { id: pto_request.id, user_id: user.id }, format: :json
      pto_request.reload
      expect(pto_request).to eq(request_before_updation)
    end

    it "should return the control back if denying already denied request" do
      pto_request = request_before_updation = FactoryGirl.create(:default_pto_request, :denied_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      get :deny, params: { id: pto_request.id, user_id: user.id }, format: :json
      pto_request.reload
      expect(pto_request).to eq(request_before_updation)
    end
  end

  describe "leave a comment as manager" do
    context "add a comment and activity" do
      before do
        @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
        get :approve, params: { id: @pto_request.id, user_id: user.id }, format: :json
        @pto_request.reload
        post :post_comment, params: { id: @pto_request.hash_id, comment: "HI", user_id: user.hash_id }, format: :json
      end

      it "should add a comment" do
        expect(@pto_request.comments.count).to eq(1)
      end

      it "should have commenter id as user id" do
        expect(@pto_request.comments.first.commenter_id).to eq(user.id)
      end

      it "should add a activity for comment" do
        expect(@pto_request.activities.where(description: "commented on the request").count).to eq(1)
      end
      it "should add activity as user" do
        expect(@pto_request.activities.where(description: "commented on the request").first.agent_id).to eq(user.id)
      end
    end
  end

  describe "aprov/deny from email for pto request with disabled policy" do
    before do
      @pto_policy = nick.pto_policies.first
      stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
      @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      @pto_policy.update(is_enabled: false)
      @pto_request.reload
    end

    it "should not approve pto request" do
      get :approve, params: { id: @pto_request.id, user_id: user.id }, format: :json
      @pto_request.reload
      expect(@pto_request.status).not_to eq("approved")
    end

    it "should not deny pto request" do
      get :deny, params: { id: @pto_request.id, user_id: user.id }, format: :json
      @pto_request.reload
      expect(@pto_request.status).not_to eq("denied")
    end

  end

  describe "aprov/deny from email for pto request with not permission" do
    before do
      nick.manager.update(user_role: nick.company.user_roles.find_by(role_type: "admin"))
      @pto_policy = nick.pto_policies.first
      @pto_request = FactoryGirl.create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)
      @pto_request.reload
    end

    it "should not approve pto request" do
      get :approve, params: { id: @pto_request.id, user_id: nick.manager.hash_id }, format: :json
      @pto_request.reload
      expect(@pto_request.status).not_to eq("approved")
      should_not redirect_to("http://#{nick.company.app_domain}/#/pto_comment/#{@pto_request.hash_id}?user_id=#{user.hash_id}&approve=1")
    end

    it "should not deny pto request" do
      get :deny, params: { id: @pto_request.id, user_id: nick.manager.hash_id }, format: :json
      @pto_request.reload
      expect(@pto_request.status).not_to eq("denied")
      should_not redirect_to("http://#{nick.company.app_domain}/#/pto_comment/#{@pto_request.hash_id}?user_id=#{user.hash_id}&approve=0")
    end

  end

  describe 'get request and user by has' do
    let(:pto_request) {create(:default_pto_request, :approved_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}

    it 'should return th pto request' do
      res = get :get_request_by_hash, params: { id: pto_request.hash_id }, format: :json
      expect(JSON.parse(res.body)['id']).to eq(pto_request.id)
    end

    it 'should return th pto request' do
      nick.manager.set_hash_id
      res = get :get_request_user, params: { id: nick.manager.hash_id }, format: :json
      expect(JSON.parse(res.body)['id']).to eq(nick.manager_id)
    end
  end

  describe 'pto_invalid' do
    let(:pto_request) {create(:default_pto_request, :approved_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id)}

    it 'should not return the pto request with invalid hash' do
      res = get :get_request_by_hash, params: { id: 'pto_request.hash_id' }, format: :json
      should redirect_to("https://#{nick.company.app_domain}/#/old_pto")
    end

    it 'should not add comment with invalid hash' do
      res = post :post_comment, params: { id: pto_request.hash_id, comment: "HI", user_id: 'user.hash_id' }, format: :json
      should redirect_to("https://#{nick.company.app_domain}/#/old_pto")
    end

  end
end
