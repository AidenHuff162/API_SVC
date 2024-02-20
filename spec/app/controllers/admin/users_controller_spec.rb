require 'rails_helper'

RSpec.describe Admin::UsersController, type: :controller do

  let(:admin_user) { create(:admin_user) }
  let(:company) { create(:company) }
  let(:user) { create(:auser, state: :active, current_stage: :registered, company: company, manager_id: user1.id) }
  let(:user1) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:location) { create(:location, name: 'Test Location', company: company) }
  let(:team) { create(:team, name: 'Test Team', company: company) }
  let(:employee) { create(:user, state: :active, current_stage: :registered, company: company, manager: user, location: location, team: team) }

  before do 
    sign_in admin_user
    allow(controller).to receive(:current_admin_user).and_return(admin_user)
  end

  describe "Restore User" do
    it "should not create user if email already exists" do
      user_a = FactoryGirl.create(:user, company: company, email: 'user_a@test.com')
      user_a_copy = FactoryGirl.build(:user, company: company, email: 'user_a@test.com')
      expect(user_a_copy.valid?).to eq(false)
    end

    it "should create user if email is already archived" do
      user_a = FactoryGirl.create(:user, company: company, email: 'user_a@test.com')

      user_a.destroy!
      expect(User.unscoped.find(user_a.id).deleted_at).not_to eq(nil)

      user_a_copy = FactoryGirl.build(:user, company: company, email: 'user_a@test.com')
      expect(user_a_copy.valid?).to eq(true)
    end

    it "should restore user and prevent to create user against the email" do
      user_a = FactoryGirl.create(:user, company: company, email: 'user_a@test.com')
      user_id = user_a.id
      user_a.destroy!
      expect(User.unscoped.find(user_id).deleted_at).not_to eq(nil)

      get :restore, params: {id: user_id}
      expect(User.unscoped.find(user_id).deleted_at).to eq(nil)

      user_a_copy = FactoryGirl.build(:user, company: company, email: 'user_a@test.com')
      expect(user_a_copy.valid?).to eq(false)
    end

    it "should not restore user if user is already exist against the email" do
      user_a = FactoryGirl.create(:user, company: company, email: 'user_a@test.com')

      user_a.destroy!
      expect(User.unscoped.find(user_a.id).deleted_at).not_to eq(nil)

      user_a_copy = FactoryGirl.create(:user, company: company, email: 'user_a@test.com')

      get :restore, params: {id: user_a.id}
      expect(User.unscoped.find(user_a.id).deleted_at).not_to eq(nil)
    end

    it "should destroy user email multiple times" do
      user_a = FactoryGirl.create(:user, company: company, email: 'user_a@test.com')
      user_a.destroy!
      expect(User.unscoped.find(user_a.id).deleted_at).not_to eq(nil)

      user_a_copy_a = FactoryGirl.create(:user, company: company, email: 'user_a@test.com')
      user_a_copy_a.destroy!
      expect(User.unscoped.find(user_a_copy_a.id).deleted_at).not_to eq(nil)

      user_a_copy_b = FactoryGirl.create(:user, company: company, email: 'user_a@test.com')
      user_a_copy_b.destroy!
      expect(User.unscoped.find(user_a_copy_b.id).deleted_at).not_to eq(nil)

      get :restore, params: {id: user_a_copy_a.id}
      expect(User.unscoped.find(user_a_copy_a.id).deleted_at).to eq(nil)

      get :restore, params: {id: user_a_copy_b.id}
      expect(User.unscoped.find(user_a_copy_b.id).deleted_at).not_to eq(nil)
    end
  end
end
