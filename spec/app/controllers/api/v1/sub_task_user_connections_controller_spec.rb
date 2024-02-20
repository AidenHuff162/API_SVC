require 'rails_helper'

RSpec.describe Api::V1::SubTaskUserConnectionsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :invited, company: company) }
  let(:workstream) { create(:workstream, company: user.company) }
  let(:task) {create(:task, workstream: workstream)}
  let!(:sub_task) {create(:sub_task,  task: task)}
  let!(:task_user_connection) {create(:task_user_connection, user: user, task: task)}

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #index" do
    it 'should return sub task user connections' do
      get :index, params: {task_user_connection_id: task_user_connection.id}, format: :json
      connections = JSON.parse(response.body)

      expect(connections.present?).to eq(true)
      expect(response.status).to eq(200)
    end
  end

  describe "PUT #update" do
    it "should update the state of sub task" do
      put :update, params: { id: sub_task.sub_task_user_connections.first.id, state: 'completed'}, format: :json
      expect(sub_task.sub_task_user_connections.first.state).to eq('completed')
    end
  end
end
