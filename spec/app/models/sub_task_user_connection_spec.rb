require 'rails_helper'

RSpec.describe SubTaskUserConnection, type: :model do
  subject(:sub_task_user_connection) { create(:sub_task_user_connection) }

  describe 'Validation' do
    describe 'SubTask' do
      it { is_expected.to validate_presence_of(:sub_task) }
    end

    describe 'TaskUserConnection' do
      it { is_expected.to validate_presence_of(:task_user_connection) }
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:task_user_connection) }
    it { is_expected.to belong_to(:sub_task) }
  end
end
