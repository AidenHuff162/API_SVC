require 'rails_helper'

RSpec.describe Api::V1::Admin::WorkstreamsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user1) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:workstream) { create(:workstream, company: user.company) }
  let(:workspace) { create(:workspace, company: user.company) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #show" do
    before do
      create_list(:workstream_with_tasks_list, 3, {company: user.company})
    end

    it "should return workstream of specific id" do
      get :show, params: { id: workstream.id }, format: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(workstream.id)
    end

    it "should return workspace image as url with workstream" do
      workspace_task = create(:task, workstream: workstream, workspace_id: workspace.id, task_type: '5')
      get :show, params: { id: workstream.id }, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:success)
      expect(json["tasks"].first["workspace"]["workspace_image"].class).to eq(String)
    end
  end

  describe "POST #update_task_owners" do
    before do
      create_list(:workstream_with_tasks_list, 3, {company: user.company})
      create(:task, workstream: workstream)
      create(:task, workstream: workstream)
    end

    it "should reassign all the task owners of workspace" do
      workspace_tasks = []
      workspace_tasks.push create(:task, workstream: workstream, workspace_id: workspace.id, task_type: '5')
      workspace_tasks.push create(:task, workstream: workstream, workspace_id: workspace.id, task_type: '5')
      workspace_tasks_id = workspace_tasks.map { |task| task.id}

      post :update_task_owners,
           params: { id: workstream.id,
           current_owner_id: "workspace",
           new_owner_id: user1.id,
           task_ids: workspace_tasks_id.join(',').to_s,
           update_task_owner: "true",
           workstream_id: workstream.id },
           format: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      task_owners = json.select { |task| workspace_tasks_id.include?(task["id"]) }.map { |task| task["owner_id"] }
      expect(task_owners).to all(be == user1.id)
    end
  end


  describe 'WorkstreamsController #bulk_update_template_task_owners' do
    it 'should reassign/delete template tasks(task_type = owner) to users as per given data array' do
      user_a = FactoryGirl.create(:user, company: company, email: "userA@test.com")
      user_b = FactoryGirl.create(:user, company: company, email: "userB@test.com")
      user_c = FactoryGirl.create(:user, company: company, email: "userC@test.com")

      task_a = create(:task, workstream: workstream, owner: user_a)
      task_b = create(:task, workstream: workstream, owner: user_a)
      task_c = create(:task, workstream: workstream, owner: user_a)

      expect(task_a.owner_id).to eq(user_a.id)
      expect(task_b.owner_id).to eq(user_a.id)
      expect(task_c.owner_id).to eq(user_a.id)
      Sidekiq::Testing.inline! do
        data_array = []
        data_array.push([task_a.id , user_b.id, false])
        data_array.push([task_b.id , user_c.id, false])
        data_array.push([task_c.id , 0, true])

        result = post :bulk_update_template_task_owners, params: { data: data_array  }, as: :json

        expect(response).to have_http_status(:success)

        task_a.reload
        task_b.reload
        task_c.reload

        expect(task_a.owner_id).to eq(user_b.id)
        expect(task_b.owner_id).to eq(user_c.id)
        expect(task_c.deleted_at).not_to eq(nil)
      end
    end
  end
end
