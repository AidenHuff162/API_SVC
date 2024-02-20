require 'rails_helper'

RSpec.describe UserRole, type: :model do
  let(:company) { create(:company, subdomain: 'role-company') }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  subject(:user_role) {FactoryGirl.create(:user_role)}
  
  describe 'Validation' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:permissions) }
    it { is_expected.to validate_presence_of(:role_type) }
    it { should validate_presence_of(:role_type) }
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to have_many(:users) }
  end

  describe 'Update' do
    it 'should update user name' do 
      expect(user_role.update(name: "anything")).to eq(true)
    end

    it 'should update the user role' do 
      expect(user_role.update(role_type: 1)).to eq(true)
    end
  end

  describe 'Destroy' do 
    it "should have users count zero" do 
      user_role = user.user_role 
      expect(user_role.valid?).to eq(true)
      user_role.run_callbacks(:destroy)
      expect(user_role.users.count).to eq(0) 
    end
  end

  describe 'User Role permission validity' do 
    it 'should validate user role with permissions' do 
      expect(user_role.valid?).to eq(true)
    end
    it 'should not validate user role without permissions' do
      user_role.permissions = nil
      expect(user_role.valid?).to eq(false)
    end
  end
end