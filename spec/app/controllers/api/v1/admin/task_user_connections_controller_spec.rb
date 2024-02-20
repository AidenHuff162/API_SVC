require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Api::V1::Admin::TaskUserConnectionsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:workstream) { create(:workstream, company: user.company) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe 'TaskUserConnectionsController #bulk_update_task_user_conenctions' do
    it 'should reassign/delete task_user_connections to users as per given data array' do
      user_a = FactoryGirl.create(:user, company: company, email: "userA@test.com")
      user_b = FactoryGirl.create(:user, company: company, email: "userB@test.com")
      user_c = FactoryGirl.create(:user, company: company, email: "userC@test.com")

      task_a = create(:task, workstream: workstream)
      task_b = create(:task, workstream: workstream)
      task_c = create(:task, workstream: workstream)

      tuc_a = create(:task_user_connection, owner: user_a, task: task_a)
      tuc_b = create(:task_user_connection, owner: user_a, task: task_b)
      tuc_c = create(:task_user_connection, owner: user_a, task: task_c)

      expect(tuc_a.owner_id).to eq(user_a.id)
      expect(tuc_b.owner_id).to eq(user_a.id)
      expect(tuc_c.owner_id).to eq(user_a.id)
      data_array = []
      data_array.push([tuc_a.id , user_b.id, false])
      data_array.push([tuc_b.id , user_c.id, false])
      data_array.push([tuc_c.id , 0, true])

      Sidekiq::Testing.inline! do
        post :bulk_update_task_user_conenctions, params: { data: data_array} , as: :json
        expect(response.status).to eq(200)
      end

      tuc_a.reload
      tuc_b.reload
      tuc_c.reload

      expect(tuc_a.owner_id).to eq(user_b.id)
      expect(tuc_b.owner_id).to eq(user_c.id)
      expect(tuc_c.deleted_at).not_to eq(nil)
    end
  end
end
