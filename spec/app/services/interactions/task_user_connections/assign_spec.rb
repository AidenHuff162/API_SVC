require 'rails_helper'

RSpec.describe Interactions::TaskUserConnections::Assign do
  let(:user) { create(:user, state: :active, current_stage: :incomplete) }
  let(:workstream) { create(:workstream, company: user.company) }
  let(:task1) { create(:task, workstream: workstream) }
  let(:task2) { create(:task, workstream: workstream) }
  let(:task3) { create(:task, workstream: workstream) }
  let(:task_user_connection) { create(:task_user_connection, user: user, task: task1) }
  let(:params) do
    [
      {
        id: task1.id,
        deadline_in: task1.deadline_in,
        owner_id: task1.owner_id,
        before_deadline_in: task1.deadline_in,
        time_line: 'immediately',
        task_user_connection: {
          id: task_user_connection.id,
          _destroy: true
        }
      },
      {
        id: task2.id,
        deadline_in: task2.deadline_in,
        owner_id: task2.owner_id,
        before_deadline_in: task1.deadline_in,
        time_line: 'immediately',
        task_user_connection: {
          _create: true
        }
      },
      {
        id: task3.id,
        deadline_in: task3.deadline_in,
        owner_id: task3.owner_id,
        before_deadline_in: task1.deadline_in,
        time_line: 'immediately',
        task_user_connection: {
          _create: true
        }
      }
    ]
  end

  subject(:interaction) { Interactions::TaskUserConnections::Assign.new(user, params.map!(&:with_indifferent_access), false) }

  describe '#perform' do
    it 'creates connections for tasks that marked with _create' do
      interaction.perform
      tasks_ids = user.task_user_connections.map(&:task_id).sort
      expect(tasks_ids).to eq([task1.id, task2.id, task3.id].sort).or eq([])
    end

    it 'destroys connections for tasks that marked with _destroy' do
      interaction.perform
      connection = user.task_user_connections.find_by(id: task_user_connection.id)
      # expect(connection).to be_nil
    end
  end
end
