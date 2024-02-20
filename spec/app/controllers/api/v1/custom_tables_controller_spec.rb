require 'rails_helper'
require 'support/permission_helper'

RSpec.describe Api::V1::CustomTablesController, type: :controller do

  let(:company) { create(:company) }
  let(:super_admin) { create(:user, company: company) }
  let(:admin) { create(:user, company: company, role: User.roles[:admin]) }
  let(:manager) { create(:user, company: company, role: User.roles[:employee]) }
  let(:employee) { create(:user, company: company, role: User.roles[:employee]) }
  let(:indirect_employee) { create(:user, manager: employee, company: company) }
  let(:location) { create(:location, company: company) }
  let(:team) { create(:team, company: company) }

  describe 'GET #home_index' do
    before do
      allow(controller).to receive(:current_company).and_return(company)
      allow(controller).to receive(:current_user).and_return(super_admin)
    end

    context "should not return custom table for unauthenticated user" do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        get :home_index, params: { user_id: super_admin.id }, format: :json
      end

      it "should return unauthorised status" do
        expect(response.status).to eq(401)
      end
    end

    context "should not return custom table for other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:other_user) { create(:user, company: other_company) }

      it 'should return forbidden status' do
        get :home_index, params: { user_id: other_user.id }, format: :json
        expect(response.status).to eq(403)
      end

      it 'should return forbidden status' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :home_index, params: { user_id: other_user.id }, format: :json
        expect(response.status).to eq(403)
      end
    end

    context "should return custom table" do
      before do
        get :home_index, params: { user_id: super_admin.id }, format: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status, 14 keys of custom table and valid keys of custom table" do
        expect(@response.status).to eq(200)
        expect(@result[0].keys.count).to eq(14)
        expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
      end
    end

    context 'should return custom table as per super admin permission' do
      context "should get own custom table index" do
        before do
          get :home_index, params: { user_id: super_admin.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return ok status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end

      context "should get admin custom table index" do
        before do
          get :home_index, params: { user_id: admin.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return ok status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end

      context "should get other user's custom table index" do
        before do
          get :home_index, params: { user_id: employee.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return ok status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end
    end

    context 'should return custom table as per admin permission' do
      before do
          allow(controller).to receive(:current_user).and_return(admin)
      end

      context "should get own custom table index, if it has permission" do
        before do
          enable_own_role_visibility(admin.user_role)
          get :home_index, params: { user_id: admin.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return ok status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end

      context "should get super admin custom table index, if it has permission" do
        before do
          enable_other_role_visibility(admin.user_role)
          get :home_index, params: { user_id: super_admin.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return ok status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end

      context "should get other user's custom table index, if it has permission" do
        before do
          enable_other_role_visibility(admin.user_role)
          get :home_index, params: { user_id: employee.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return ok status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end

      context 'should filter custom table using location' do
        before do
          enable_other_role_visibility(admin.user_role)
        end

        context 'should return empty custom table if employee location is empty' do
          before do
            admin.user_role.update!(location_permission_level: [location.id.to_s])
            get :home_index, params: { user_id: employee.id }, format: :json
          end

          it "should return 204 status with empty response body" do
            expect(response.status).to eq(204)
            expect(response.body.empty?).to eq(true)
          end
        end

        context 'should return custom table if employee and role location are same' do
          before do
            employee.update!(location: location )
            get :home_index, params: { user_id: employee.id }, format: :json
            @result = JSON.parse(response.body)
          end

          it "should return ok status with necessary keys" do
            expect(response.status).to eq(200)
            expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
          end
        end
      end

      context 'should filter custom table using team' do
        before do
          enable_other_role_visibility(admin.user_role)
        end

         context 'should return empty custom table if employee team is empty' do
          before do
            admin.user_role.update!(team_permission_level: [team.id.to_s])
            get :home_index, params: { user_id: employee.id }, format: :json
          end

          it "should return 204 status with empty response" do
            expect(response.status).to eq(204)
            expect(response.body.empty?).to eq(true)
          end
        end

        context 'should return custom table if employee and role team are same' do
          before do
            employee.update!(team: team)
            get :home_index, params: { user_id: employee.id }, format: :json
            @result = JSON.parse(response.body)
          end

          it "should return ok status with necessary keys" do
            expect(response.status).to eq(200)
            expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
          end
        end
      end


      context 'should filter custom table using employee type' do
        before do
          enable_other_role_visibility(admin.user_role)
        end

         context 'should return empty custom table if employee role is empty' do
          before do
            admin.user_role.update!(status_permission_level: ["Full Time"])
            get :home_index, params: { user_id: employee.id }, format: :json
          end

          it "should return 204 status with empty response" do
            expect(response.status).to eq(204)
            expect(response.body.empty?).to eq(true)
          end
        end

        context 'should return custom table if employee and role are same' do
          before do
            employee.custom_field_values << FactoryGirl.create(:custom_field_value, value_text: nil, custom_field: CustomField.find_by(field_type: CustomField.field_types[:employment_status]), custom_field_option: CustomFieldOption.find_by(option: "Full Time"))
            get :home_index, params: { user_id: employee.id }, format: :json
            @result = JSON.parse(response.body)
          end

          it "should return ok status with necessary keys" do
            expect(response.status).to eq(200)
            expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
          end
        end
      end
    end

    context 'should return custom table as per manager permission' do
      before do
        employee.update(manager_id: manager.id)
        manager.reload
        allow(controller).to receive(:current_user).and_return(manager)
      end

      context 'should get own custom table index, if it has permission' do
        before do
          enable_own_role_visibility(manager.user_role)
          get :home_index, params: { user_id: manager.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return ok status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end

      context "should not get super admin custom table index, if it is not managed by manager" do
        before do
          enable_other_role_visibility(manager.user_role)
          get :home_index, params: { user_id: super_admin.id }, format: :json
        end

        it "should return 204 status with empty body" do
          expect(response.status).to eq(204)
          expect(response.body.empty?).to eq(true)
        end
      end

      context "should get super admin custom table index, if it is managed by manager" do
        before do
          enable_other_role_visibility(manager.user_role)
          super_admin.update!(manager_id: manager.id)
          get :home_index, params: { user_id: super_admin.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return 200 status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end

      context "should not get admin custom table index, if it is not managed by manager" do
        before do
          enable_other_role_visibility(manager.user_role)
          get :home_index, params: { user_id: admin.id }, format: :json
        end

        it "should return 204 status with empty body" do
          expect(response.status).to eq(204)
          expect(response.body.empty?).to eq(true)
        end
      end

      context "should get admin custom table index, if it is managed by manager" do
        before do
          enable_other_role_visibility(manager.user_role)
          admin.update!(manager_id: manager.id)
          get :home_index, params: { user_id: admin.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return 200 status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end

      context "should get employee custom table index, if it is managed by manager and reporting level is direct" do
        before do
          enable_other_role_visibility(manager.user_role)
          manager.user_role.update!(reporting_level: UserRole.reporting_levels[:direct])
          get :home_index, params: { user_id: employee.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return 200 status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end

      context "should get indirect employee custom table index, if it is managed by manager and reporting level is direct and indirect" do
        before do
          enable_other_role_visibility(manager.user_role)
          get :home_index, params: { user_id: indirect_employee.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return 200 status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end

      context "should not get indirect employee custom table index, if reporting level is direct" do
        before do
          enable_other_role_visibility(manager.user_role)
          manager.user_role.update!(reporting_level: UserRole.reporting_levels[:direct])
          get :home_index, params: { user_id: indirect_employee.id }, format: :json
        end

        it "should return 204 status with empty body" do
          expect(response.status).to eq(204)
          expect(response.body.empty?).to eq(true)
        end
      end
    end

    context 'should return custom table as per manager permission' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      context 'should get own custom table index, if it has permission' do
        before do
          enable_own_role_visibility(employee.user_role)
          get :home_index, params: { user_id: employee.id }, format: :json
          @result = JSON.parse(response.body)
        end

        it "should return ok status with necessary keys" do
          expect(response.status).to eq(200)
          expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_user_snapshots", "count", "custom_table_property", "custom_fields", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "expiry_date", "approval_chains"])
        end
      end


      context "should not get super admin custom table index, if it has no permission" do
        before do
          disable_other_role_visibility(employee.user_role)
          get :home_index, params: { user_id: super_admin.id }, format: :json
        end

        it "should return 204 status with empty body" do
          expect(response.status).to eq(204)
          expect(response.body.empty?).to eq(true)
        end
      end


      context "should not get admin custom table index, if it has no permission" do
        before do
          disable_other_role_visibility(employee.user_role)
          get :home_index, params: { user_id: admin.id }, format: :json
        end

        it "should return 204 status with empty body" do
          expect(response.status).to eq(204)
          expect(response.body.empty?).to eq(true)
        end
      end


      context "should not get manager custom table index, if it has no permission" do
        before do
          disable_other_role_visibility(employee.user_role)
          get :home_index, params: { user_id: manager.id }, format: :json
        end

        it "should return 204 status with empty body" do
          expect(response.status).to eq(204)
          expect(response.body.empty?).to eq(true)
        end
      end
    end
  end
end
