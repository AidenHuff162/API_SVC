require 'rails_helper'

RSpec.describe SubTask, type: :model do
  subject(:sub_task) { create(:sub_task) }

  describe 'Validation' do
    describe 'Title' do
      it { is_expected.to validate_presence_of(:title) }
    end

    describe 'Task' do
      it { is_expected.to validate_presence_of(:task).on(:update) }
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:task) }
    it { is_expected.to have_many(:task_user_connections).through(:sub_task_user_connections) }
    it { is_expected.to have_many(:sub_task_user_connections).dependent(:destroy) }
  end

  describe 'States' do
    it 'Verifies initial state' do
      expect(sub_task.state).to eq('in_progress')
    end

    it 'Verifies value after complete state transition' do
      sub_task.complete!
      expect(sub_task.state).to eq('completed')
    end
  end
end
