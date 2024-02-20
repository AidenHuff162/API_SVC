require 'rails_helper'

RSpec.describe Api::V1::UserRolesController, type: :controller do

  let(:company) { create(:company) }
  let(:company2) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user2) { create(:user, state: :active, current_stage: :registered, role: 'employee', company: company2) }
  let(:admin_user) {create(:peter, company:company)}
  let(:admin_role) {create(:admin_role, company: company)}


  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe "Authorize" do
    describe "User Role" do
      context 'user of (current) company' do
        it 'can manage user role' do
          allow(controller).to receive(:current_user).and_return(user)
          ability = Ability.new(user)
          expect(ability.can?(:manage, admin_role)).to eq(true)
        end
      end
    end
  end
  describe "Unauthorize" do
    describe "User Role" do
      context 'user of (different) company' do
        it 'can not manage user role' do
          allow(controller).to receive(:current_user).and_return(user2)
          ability = Ability.new(user2)
          expect(ability.cannot?(:manage, admin_role)).to eq(true)
        end
      end
    end
  end

  describe 'updating the user role' do
    context 'super admin permissions cannot be updated by' do
      context 'super admin' do
        it 'should not allow to update permission' do
          res = put :update, params: { id: user.user_role_id, name: 'sdf', permissions: user.user_role.permissions, sub_tab: 'permissions' }, format: :json
          expect(res.status).to eq(204)
        end
      end

      context 'admin' do
        before do
          allow(controller).to receive(:current_user).and_return(admin_user)
        end
        it 'should not allow to update permission' do
          res = put :update, params: { id: user.user_role_id, name: 'sdf', sub_tab: 'permissions', permissions: user.user_role.permissions }, format: :json
          expect(res.status).to eq(204)
        end
      end
    end

    context 'admin permissions updated by' do
      context 'super admin' do
        it 'should allow to update permission' do
          res = put :update, params: { id: admin_user.user_role_id, name: 'sdf', sub_tab: 'permissions', permissions: admin_user.user_role.permissions }, format: :json
          expect(res.status).to eq(200)
        end
      end

      context 'admin' do
        before do
          allow(controller).to receive(:current_user).and_return(admin_user)
        end
        it 'should not allow to update own permissions' do
          res = put :update, params: { id: admin_user.user_role_id, name: 'sdf', sub_tab: 'permissions', permissions: admin_user.user_role.permissions }, format: :json
          expect(res.status).to eq(204)
        end

        context 'admin updating other admin permissions' do
          context 'with no_access of permission' do
            it 'should not allow to update others permissions' do
              res = put :update, params: { id: admin_role.id, name: 'sdf', sub_tab: 'permissions', permissions: admin_role.permissions }, format: :json
              expect(res.status).to eq(204)
            end
          end

          context 'with view_only of permission' do
            before do
              admin_user.user_role.permissions['admin_visibility']['permissions'] = 'view_only'
              admin_user.save!
            end
            it 'should not allow to update others permissions' do
              res = put :update, params: { id: admin_role.id, name: 'sdf', sub_tab: 'permissions', permissions: admin_role.permissions }, format: :json
              expect(res.status).to eq(204)
            end
          end

          context 'with view_and_edit of permission' do
             before do
              admin_user.user_role.permissions['admin_visibility']['permissions'] = 'view_and_edit'
              admin_user.save!
            end
            it 'should allow to update others permissions' do
              res = put :update, params: { id: admin_role.id, name: 'sdf', sub_tab: 'permissions', permissions: admin_role.permissions }, format: :json
              expect(res.status).to eq(200)
            end
          end
        end
      end
    end
  end

  describe 'GET index' do
    it 'should return all user roles' do
      get :index, params: { company_id: company.id, sub_tab: 'permissions' }, format: :json
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Manager" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Ghost Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Super Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Employee" }).not_to be_nil
    end

    it 'should return all user roles' do
      get :full_index, params: { company_id: company.id, sub_tab: 'permissions' }, format: :json
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Manager" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Ghost Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Super Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Employee" }).not_to be_nil
    end

    it 'should return all user roles' do
      get :home_index, params: { company_id: company.id, sub_tab: 'permissions' }, format: :json
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Manager" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Ghost Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Super Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Employee" }).not_to be_nil
    end

    it 'should return all user roles' do
      get :simple_index, params: { company_id: company.id, sub_tab: 'permissions' }, format: :json
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Manager" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Ghost Admin" }).to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Super Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Employee" }).not_to be_nil
    end

    it 'should return all user roles' do
      get :custom_alert_page_index, params: { company_id: company.id, sub_tab: 'permissions' }, format: :json
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Manager" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Ghost Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Super Admin" }).not_to be_nil
      expect(JSON.parse(response.body).find{ |role| role["name"] == "Employee" }).not_to be_nil
    end
  end

  describe "GET Show" do
    it 'shhould show user role' do
      get :show, params: { id: admin_role.id }, format: :json
      expect(JSON.parse(response.body)["id"]).to eq(admin_role.id)
    end
    it 'should not show user role' do
      admin_role = nil
      expect{ get :show,
              params: { id: admin_role.id },
              format: :json
            }.to raise_error
    end
  end

  describe "Destroy" do
    it 'should delete admin_role if id exists' do
       delete :destroy, params: { id: admin_role.id }, format: :json
       expect(response.status).to eq(204)
    end
    it 'should not delete the user role with wrong id' do
       delete :destroy, params: { id: 1231123 }, format: :json
       expect(JSON.parse(response.body)["errors"].first["title"]).to eq("Not Found")
    end
  end

  describe "create" do
    context "authenticate user" do
      it ' can create user role' do
        post :create, params: { name: "anything", description: 'this is the description of user role', role_type: admin_role.role_type, permissions:admin_role.permissions  }, format: :json
        expect(response.message).to eq('Created')
      end
    end
    context "unauthenticate user" do
      it 'can not create user role without permissions' do
        post :create, params: { name: "anything", description: 'this is the description of user role which will not create', role_type: nil, permissions: nil  }, format: :json
        expect(response.status).to eq(422)
      end
    end
  end

  describe "user role" do
    context 'unauthenticated user' do
      it 'should not allow to remove user role' do
        expect{ get :remove_user_role,
                params: { user_id: user2.id },
                format: :json
              }.to raise_error
      end
      it 'should not allow to add user role' do
        get :add_user_role, params: { user_id: user2.id, role_id: admin_role.id }, format: :json
        expect(user2.reload.user_role_id).not_to eq(admin_role.id)
      end
    end
    context 'authenticated user' do
      it 'should allow to remove user role' do
        get :remove_user_role, params: { user_id: user.id }, format: :json
        expect(response.status).to eq(200)
      end
      it 'should allow to add user role' do
        get :add_user_role, params: { user_id: user.id, role_id: admin_role.id  }, format: :json
        expect(response.status).to eq(200)
      end
    end
  end
end
