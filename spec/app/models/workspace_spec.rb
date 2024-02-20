require 'rails_helper'

RSpec.describe Workspace, type: :model do

  describe 'Validation' do
    describe 'Name' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'Workspace Image' do
      it { is_expected.to validate_presence_of(:workspace_image_id) }
    end
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:workspace_image) }
    it { is_expected.to have_many(:members).through(:workspace_members) }
    it { is_expected.to have_many(:workspace_members).dependent(:destroy) }
    it { is_expected.to have_many(:task_user_connections).dependent(:nullify) }
    it { is_expected.to have_many(:tasks).dependent(:nullify) }
  end
end
