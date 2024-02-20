require 'rails_helper'

RSpec.describe Api::V1::EmailActivitiesController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, role: 2 ) }
  let(:workstream) {create(:workstream, company: company)}
  let(:task) {create(:task, workstream: workstream)}
  let(:task_user_connection) {create(:task_user_connection, user: user, task: task)}
  before do
    allow(controller).to receive(:current_company).and_return(company)
  end
  describe '#index' do
    context 'completing activities' do
      before do
        get :index, params: { task: [task_user_connection.token] }
        task_user_connection.reload
      end

      it 'should change the state to complete' do
        expect(task_user_connection.state).to eq("completed")
      end

      it 'should set completeion method to email' do
        expect(task_user_connection.completed_by_method).to eq("email")
      end

      it 'should redirect to activities_completed' do
        response.should redirect_to "https://#{company.app_domain}/#/activities_completed"
      end
    end

    context 'different company' do
      it 'should now allow to complete activities for different company' do
        allow(controller).to receive(:current_company).and_return(create(:company, subdomain: 'rab'))
        get :index, params: { task: [task_user_connection.token] }
        expect(task_user_connection.state).to_not eq("completed")
      end
    end
  end
end
