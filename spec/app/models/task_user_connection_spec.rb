require 'rails_helper'

RSpec.describe TaskUserConnection, type: :model do
  subject(:task_user_connection) { create(:task_user_connection) }

  let(:scheduled_task) { create(:scheduled_task, workstream: create(:workstream)) }
  subject(:scheduled_task_user_connection) { create(:scheduled_task_user_connection, task: scheduled_task) }

  describe 'Validation' do
    describe 'User' do
      it { is_expected.to validate_presence_of(:user) }
    end

    describe 'Task' do
      it { is_expected.to validate_presence_of(:task) }
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:task) }
    it { is_expected.to belong_to(:owner) }
    it { is_expected.to have_many(:sub_tasks).through(:sub_task_user_connections) }
    it { is_expected.to have_many(:sub_task_user_connections).dependent(:destroy) }
    it { is_expected.to belong_to(:workspace) }
  end

  describe 'After Update' do

    context 'if due date changed, then create task activity' do
      it 'should create activity, if due date have changed and agent is present' do
        agent = create(:user)
        expect{ task_user_connection.update(due_date: Date.today + 4, agent_id: agent.id) }.to change{ task_user_connection.activities.count }.by(1)
      end

      it 'should not create activity, if due date have changed and agent is not present' do
        agent = create(:user)
        expect{ task_user_connection.update(due_date: Date.today + 4) }.to change{ task_user_connection.activities.count }.by(0)
      end

      it 'should not create activity, if due date have not changed and agent is present' do
        agent = create(:user)
        expect{ task_user_connection.update(due_date: task_user_connection.due_date, agent_id: agent.id) }.to change{ task_user_connection.activities.count }.by(0)
      end

      it 'should not create activity, if due date have not changed and agents is not present' do
        agent = create(:user)
        expect{ task_user_connection.update(due_date: task_user_connection.due_date) }.to change{ task_user_connection.activities.count }.by(0)
      end
    end

    context 'if due date changed, then update before due date' do
      it 'should not change before due date, if schedule days gap is not present' do
        task_user_connection.update(due_date: Date.today + 4)
        expect(task_user_connection.due_date).to eq(Date.today + 4)
        expect(task_user_connection.before_due_date).to eq(nil)
      end

      it 'should change before due date, if schedule days gap is present' do
        scheduled_task_user_connection.update(due_date: Date.today + 4)
        expect(scheduled_task_user_connection.due_date).to eq(Date.today + 4)
        expect(scheduled_task_user_connection.before_due_date).to eq(scheduled_task_user_connection.user.start_date + scheduled_task_user_connection.task.deadline_in + scheduled_task_user_connection.schedule_days_gap)
      end
    end

    context 'if due date changed, then update calendar event' do
      it 'should not change calendar event date range, if due date is not changed' do
        task_user_connection.update(due_date: task_user_connection.due_date)
        expect(task_user_connection.calendar_events.last.event_start_date).to eq(task_user_connection.due_date)
        expect(task_user_connection.calendar_events.last.event_end_date).to eq(task_user_connection.due_date)
      end

      it 'should change calendar event date range, if due date is changed' do
        task_user_connection.update(due_date: Date.today + 4)
        expect(task_user_connection.calendar_events.last.event_start_date).to eq(Date.today + 4)
        expect(task_user_connection.calendar_events.last.event_end_date).to eq(Date.today + 4)
      end
    end
  end

  describe 'After delete task' do
    it 'should not delete task user connections' do
      id = task_user_connection.id
      task_user_connection.task.destroy
      task_user_connection = TaskUserConnection.with_deleted.find id
      expect(task_user_connection.task.deleted_at).not_to eq(nil)
      expect(task_user_connection.deleted_at).not_to eq(nil)
    end
  end

  describe 'overdue?' do
    it 'should check task user connection is not overdue' do
      res = task_user_connection.overdue?
      expect(res).to eq(false)
    end

    it 'should check task user connection is overdue' do
      task_user_connection.update(due_date: Date.today - 5.days)
      res = task_user_connection.overdue?
      expect(res).to eq(true)
    end
  end

  describe 'mark_task_completed' do
    it 'should mark task completed' do
      task_user_connection.mark_task_completed
      expect(task_user_connection.state).to eq('completed')
    end
  end

  describe 'update_jira_issue_state' do
    it 'should update jira issue state' do
      job_size = Sidekiq::Queues["default"].size
      task_user_connection.update_jira_issue_state
      expect(Sidekiq::Queues["default"].size).to eq(job_size + 3)
    end
  end

  describe 'generate_token' do
    it 'should generate token' do
      task_user_connection.generate_token
      expect(task_user_connection.token.present?).to eq(true)
    end
  end

  describe 'complete_asana_task' do
    it 'should complete asana task' do
      job_size = Sidekiq::Queues["asana_integration"].size
      task_user_connection.complete_asana_task
      expect(Sidekiq::Queues["asana_integration"].size).to eq(job_size + 1)
    end
  end

  describe 'destroy_asana_task' do
    it 'should destroy asana task' do
      allow_any_instance_of(AsanaService::DestroyTask).to receive(:perform).and_return(true)
      res = task_user_connection.destroy_asana_task
      expect(res).to eq(true)
    end
  end
end
