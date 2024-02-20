require 'rails_helper'

RSpec.describe Api::V1::TasksController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :invited, company: company) }
  let(:workstream){ create(:workstream, company: company )}
  let(:task){ create(:task, workstream: workstream )}
  let!(:task_user_connection){ create(:task_user_connection, task: task, user: user)}

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #index" do
    it 'should return sub task user connections' do
      get :index, params: {user_id: user.id}, format: :json
      tasks = JSON.parse(response.body)

      expect(tasks.present?).to eq(true)
      expect(response.status).to eq(200)
    end
  end

  describe "PUT #update" do
    it "should update the task and create history" do
      put :update, params: { id: task.id, workstream: {name: workstream.name}, name: task.name, task_type: task.task_type, task_user_connections: [task_user_connection.as_json] }, format: :json
      company.reload
      expect(company.history_ids.count).to eq(1)
    end
  end
end
