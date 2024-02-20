require 'rails_helper'

RSpec.describe Api::V1::CommentsController, type: :controller do
  let(:current_company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: current_company) }
  let(:workstream) { create(:workstream, company: current_company) }
  let(:task1) { create(:task, workstream: workstream) }
  let(:task2) { create(:task, workstream: workstream) }
  let(:deleted_task_connection) { create(:task_user_connection, task: task1, user: user, deleted_at: 3.days.ago) }
  let(:task_user_connection) { create(:task_user_connection, task: task2, user: user, agent_id: user.id) }
  let(:policy) { create(:default_pto_policy, :policy_with_expiry_carryover, company: current_company)}
  let(:assigned_policy) { create(:assigned_pto_policy, user: user, pto_policy: policy, balance: 20, carryover_balance: 20)}
  before {User.current = user}
  let(:pto_request) { create(:pto_request, user: user, pto_policy: policy, partial_day_included: false, status: 0, begin_date: 10.days.from_now.to_date, end_date: 12.days.from_now.to_date, balance_hours: 24) }
  let(:deleted_pto_request) { create(:pto_request, user: user, pto_policy: policy, partial_day_included: false, status: 0, begin_date: 10.days.from_now.to_date, end_date: 12.days.from_now.to_date, balance_hours: 24, deleted_at: 10.days.ago) }

  describe "Unsigned user cannot access the function" do
    it "#create" do
      post :create, format: :json
      expect(response).to have_http_status(404)
    end

    it "#index" do
      get :index, format: :json
      expect(response).to have_http_status(404)
    end
  end

  describe "Get #create" do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_company).and_return(user.company)
    end

    it "should create a comment for task" do
      post :create, params: { task_user_connection_id: task_user_connection.id, commenter_id: user.id, user_id: user.id, description: Faker::Hipster.sentence, company_id: current_company.id }, format: :json
      expect(response).to have_http_status(:success)
      expect(task_user_connection.comments.count).to eq(1)
    end

    it "should create a comment for task without company_id" do
      post :create, params: { task_user_connection_id: task_user_connection.id, commenter_id: user.id, user_id: user.id, description: Faker::Hipster.sentence }, format: :json
      expect(response).to have_http_status(:success)
      expect(task_user_connection.comments.count).to eq(1)
    end

    it "should create a comment for deleted task" do
      post :create, params: { task_user_connection_id: deleted_task_connection.id, commenter_id: user.id, user_id: user.id, description: Faker::Hipster.sentence }, format: :json
      expect(response).to have_http_status(:success)
      expect(deleted_task_connection.comments.count).to eq(1)
    end

    it "should create a comment for pto request" do
      post :create, params: { pto_id: pto_request.id, commenter_id: user.id, user_id: user.id, description: Faker::Hipster.sentence }, format: :json
      expect(response).to have_http_status(:success)
      expect(pto_request.comments.count).to eq(1)
    end

    it "should create a comment for deleted pto request" do
      post :create, params: { pto_id: deleted_pto_request.id, commenter_id: user.id, user_id: user.id, description: Faker::Hipster.sentence }, format: :json
      expect(response).to have_http_status(:success)
      expect(deleted_pto_request.comments.count).to eq(1)
    end
  end

  describe "GET #index" do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_company).and_return(user.company)
    end

    it "should return array task comments" do
      FactoryGirl.create(:comment, commenter: user, commentable: task_user_connection , commentable_type: "TaskUserConnection", company_id: current_company.id)
      FactoryGirl.create(:comment, commenter: user, commentable: task_user_connection , commentable_type: "TaskUserConnection", company_id: current_company.id)
   
      get :index, params: { task_user_connection_id: task_user_connection.id, user_id: user.id }, format: :json
      json = JSON.parse response.body

      expect(response).to have_http_status(:success)
      expect(json.count).to be(2)
    end

    it "should return array pto request comments" do
      FactoryGirl.create(:comment, commentable_id: pto_request.id, commentable_type: "PtoRequest", commenter_id: user, company_id: current_company.id)
      FactoryGirl.create(:comment, commentable_id: pto_request.id, commentable_type: "PtoRequest", commenter_id: user, company_id: current_company.id)

      get :index, params: { pto_id: pto_request.id, user_id: user.id }, format: :json
      json = JSON.parse response.body

      expect(response).to have_http_status(:success)
      expect(json.count).to be(2)
    end
  end
end
