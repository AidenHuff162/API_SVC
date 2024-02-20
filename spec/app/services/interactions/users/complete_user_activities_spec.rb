require 'rails_helper'

RSpec.describe Interactions::Users::CompleteUserActivities do

  describe 'complete activities' do
    let(:workstream) { create(:workstream, company: user.company) }
    let(:task1) { create(:task, workstream: workstream) }
    let(:task2) { create(:task, workstream: workstream) }

    context 'onboarding user' do
      let(:user) { create(:user, state: :active,  current_stage: :first_week) }
      let!(:task_user_connection) { create(:task_user_connection, user: user, task: task1, state: 'in_progress') }
      before { Interactions::Users::CompleteUserActivities.new(user).perform}
      it 'should complete the task and change user stage' do
        expect(task_user_connection.reload.state).to eq('completed')
        expect(user.reload.current_stage).to eq('pre_start')
      end
    end

    context 'preboarding user' do
      let(:user) { create(:user, state: :active) }
      let!(:task_user_connection) { create(:task_user_connection, user: user, task: task1, state: 'in_progress') }
      before { Interactions::Users::CompleteUserActivities.new(user).perform}
      it 'should complete the task and should not change user stage' do
        expect(task_user_connection.reload.state).to eq('completed')
        expect(user.reload.current_stage).to eq('preboarding')
      end
    end

    context 'offboarding user' do
      let(:user) { create(:user, state: :active, current_stage: :last_week, termination_date: Date.today - 2.days ) }
      let!(:task_user_connection) { create(:task_user_connection, user: user, task: task1, state: 'in_progress') }
      before { Interactions::Users::CompleteUserActivities.new(user).perform}
      it 'should complete the task' do
        expect(task_user_connection.reload.state).to eq('completed')
      end
    end

    context 'multiple task' do
      let(:user) { create(:user, state: :active) }
      let!(:task_user_connection) { create(:task_user_connection, user: user, task: task1, state: 'in_progress') }
      let!(:task_user_connection2) { create(:task_user_connection, user: user, task: task2, state: 'in_progress') }
      before { Interactions::Users::CompleteUserActivities.new(user).perform}
      it 'should complete the tasks' do
        expect(task_user_connection.reload.state).to eq('completed')
        expect(task_user_connection2.reload.state).to eq('completed')
      end
    end

    context 'complete task' do
      let(:user) { create(:user, state: :active) }
      let!(:task_user_connection) { create(:task_user_connection, user: user, task: task1, state: 'completed') }
      before { Interactions::Users::CompleteUserActivities.new(user).perform}
      it 'should not affect the tasks' do
        expect(task_user_connection.reload.state).to eq('completed')
      end
    end

    context 'offboarding user with termination_date of future' do
      let(:user) { create(:user, state: :active, current_stage: :last_week, termination_date: Date.today + 2.days ) }
      before { Interactions::Users::CompleteUserActivities.new(user).perform}
      it 'should not change user stage' do
        expect(user.reload.current_stage).to eq('last_week')
      end
    end


  end

end
