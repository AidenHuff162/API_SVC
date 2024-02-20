require 'rails_helper'

RSpec.describe Api::V1::ActivitiesController, type: :controller do

  let(:user) { create(:user_with_tasks) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe 'Post #create' do
    it "It should created by task-user-connection association" do
      task_user_connection = user.task_user_connections.take
      post :create, params: {task_user_connection_id: task_user_connection.id, agent_id: user.id, description: Faker::Hipster.sentence} , format: :json
      expect(response).to have_http_status(:success)
      expect(task_user_connection.activities.count).to eq(1)
    end
  end

  describe 'Not allowed any action without login' do
    before do
      allow(controller).to receive(:current_user).and_return(nil)
    end
    it "It should not allow to create activity" do
      task_user_connection = user.task_user_connections.take
      post :create, params: {task_user_connection_id: task_user_connection.id, agent_id: user.id, description: Faker::Hipster.sentence}, format: :json
      expect(response.status).to eq(401)
    end

    it "It should not return activities" do
      task_user_connection = user.task_user_connections.take
      get :index, params: {task_user_connection_id: task_user_connection.id} , format: :json
      expect(response.status).to eq(401)
    end
  end

  describe 'Get #index' do
    it "It should return zero activities" do
      task_user_connection = user.task_user_connections.take
      get :index, params: {task_user_connection_id: task_user_connection.id}, format: :json
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body.to_s).count).to eq(0)
    end

    it "It should return one activity" do
      task_user_connection = user.task_user_connections.take      
      post :create, params: {task_user_connection_id: task_user_connection.id, agent_id: user.id, description: Faker::Hipster.sentence}, format: :json
      expect(response).to have_http_status(:success)
      get :index, params: {task_user_connection_id: task_user_connection.id}, format: :json
      expect(JSON.parse(response.body.to_s).count).to eq(1)
    end
  end
end
