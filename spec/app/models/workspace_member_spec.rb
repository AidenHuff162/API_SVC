require 'rails_helper'

RSpec.describe WorkspaceMember, type: :model do

  describe 'Validation' do
    describe 'validates uniqueness of workspace_id scoped to member_id' do
      subject { WorkspaceMember.new(workspace_id: 1, member_id: 1) }
      it { is_expected.to validate_uniqueness_of(:workspace_id).scoped_to(:member_id) }
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:member) }
    it { is_expected.to belong_to(:workspace) }
  end
end
