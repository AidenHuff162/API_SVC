require 'rails_helper'
require 'support/permission_helper'

RSpec.describe Api::V1::Admin::CustomTablesController, type: :controller do

  let(:company) { create(:company) }
  let(:super_admin) { create(:user, role: :account_owner, company: company) }
  let(:admin) { create(:user, role: :admin, company: company) }
  let(:manager) { create(:user, role: :employee, company: company) }
  let(:employee) { create(:user, role: :employee, company: company) }
  let(:custom_table) { create(:custom_table, company: company) }

  before do
    employee.update!(manager_id: manager.id)
    manager.reload
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'GET #reporting index' do
    context "should show custom table for reporting index" do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
        get :reporting_index, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status and 6 keys of custom table and valid keys of custom table and 5 keys of custom fields and valid keys of custom fields" do
        expect(response.status).to eq(200)
        expect(@result[0].keys.count).to eq(6)
        expect(@result[0].keys).to eq(["id", "name", "position", "table_type", "custom_table_property", "custom_fields"])
        expect(@result[0]['custom_fields'][0].keys.count).to eq(7)
        expect(@result[0]['custom_fields'][0].keys).to eq(["id", "name", "field_type", "position", "custom_table_id", "custom_field_options", "sub_custom_fields"])
      end
    end

    context "should not return custom table for unauthenticated user" do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        get :reporting_index, as: :json
      end

      it "should return unauthorised status" do
        expect(response.status).to eq(401)
      end
    end

    context "should not return custom table for other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:other_user) { create(:user, company: other_company) }

      it 'should return forbidden status' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :reporting_index, as: :json
        expect(response.status).to eq(403)
      end
    end

    context 'admins should have permissions to get custom table for reporting index' do
      before do
        allow(controller).to receive(:current_user).and_return(admin)
      end

      it 'should return 200 status and empty custom tables if other role visibility has no access' do
        get :reporting_index, as: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).empty?).to eq(true)
      end

      it 'should return custom tables if other role visibility has view and edit access' do
        enable_other_role_visibility(admin.user_role)
        get :reporting_index, as: :json
        expect(JSON.parse(response.body).empty?).to eq(false)
      end
    end

    context 'super admins should have permissions to get custom table for reporting index' do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
      end

      it 'should return 200 status and custom tables' do
        get :reporting_index, as: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body).empty?).to eq(false)
      end
    end

    context 'employee should not have permission to get custom table for reporting index' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      it 'should return 403 status' do
        get :index, as: :json
        expect(response.status).to eq(403)
      end
    end

    context 'manager should not have permission to get custom table for reporting index' do
      before do
        allow(controller).to receive(:current_user).and_return(manager)
      end

      it 'should return 403 status' do
        get :index, as: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe 'GET #permission page index' do
    context "should show custom table for permission page index" do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
        get :permission_page_index, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status and 3 keys of custom table and valid keys of custom table" do
        expect(response.status).to eq(200)
        expect(@result[0].keys.count).to eq(3)
        expect(@result[0].keys).to eq(["id", "name", "position"])
      end
    end

    context "should not return custom table for unauthenticated user" do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        get :permission_page_index, as: :json
      end

      it "should return unauthorised status" do
        expect(response.status).to eq(401)
      end
    end

    context "should not return custom table for other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:other_user) { create(:user, company: other_company) }

      it 'should return forbidden status' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :permission_page_index, as: :json
        expect(response.status).to eq(403)
      end
    end

    context 'admins should have access to get custom table for permission page index' do
      before do
        allow(controller).to receive(:current_user).and_return(admin)
      end

      it 'should return 200 status' do
        get :permission_page_index, as: :json
        expect(response.status).to eq(200)
      end
    end

   context 'super admins should have access to get custom table for permission page index' do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
      end

      it 'should return 200 status' do
        get :permission_page_index, as: :json
        expect(response.status).to eq(200)
      end
    end

    context 'employee should not have access to get custom table for permission page index' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      it 'should return 403 status' do
        get :permission_page_index, as: :json
        expect(response.status).to eq(403)
      end
    end

    context 'manager should not have access to get custom table for permission page index' do
      before do
        allow(controller).to receive(:current_user).and_return(manager)
      end

      it 'should return 403 status' do
        get :permission_page_index, as: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe 'GET #group page index' do
    context "should show custom table for group page index" do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
        get :group_page_index, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status and 2 keys of custom table and valid keys of custom table" do
        expect(response.status).to eq(200)
        expect(@result[0].keys.count).to eq(2)
        expect(@result[0].keys).to eq(["id", "name"])
      end
    end

    context "should not return custom table for unauthenticated user" do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        get :group_page_index, as: :json
      end

      it "should return unauthorised status" do
        expect(response.status).to eq(401)
      end
    end

    context "should not return custom table for other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:other_user) { create(:user, company: other_company) }

      it 'should return forbidden status' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :group_page_index, as: :json
        expect(response.status).to eq(403)
      end
    end

    context 'admins should have access to get custom table for group page index' do
      before do
        allow(controller).to receive(:current_user).and_return(admin)
      end

      it 'should return 200 status' do
        get :group_page_index, as: :json
        expect(response.status).to eq(200)
      end
    end

   context 'super admins should have access to get custom table for group page index' do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
      end

      it 'should return 200 status' do
        get :group_page_index, as: :json
        expect(response.status).to eq(200)
      end
    end
    context 'employee should not have access to get custom table for group page index' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      it 'should return 403 status' do
        get :group_page_index, as: :json
        expect(response.status).to eq(403)
      end
    end

    context 'manager should not have access to get custom table for group page index' do
      before do
        allow(controller).to receive(:current_user).and_return(manager)
      end

      it 'should return 403 status' do
        get :group_page_index, as: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe 'POST #Create' do
    before do
        allow(controller).to receive(:current_user).and_return(super_admin)
      end

    context 'should not create custom table' do
      it "should not create custom table if name is not present" do
        post :create, params: { table_type: CustomTable.table_types[:timeline] }, as: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it "should not create custom table if table type was nil" do
        post :create, params: { name: 'Sample Custom Table', table_type: nil }, as: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it "should not create custom table if name and table type is not present" do
        post :create, as: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it "should not create custom table of same name" do
        FactoryGirl.create(:custom_table, company: company)
        post :create, params: { name: 'Sample Custom Table', table_type: CustomTable.table_types[:timeline] }, as: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it "should not create custom table if expiry time is not present" do
        post :create, params: { name: 'Sample Custom Table', is_approval_required: true }, as: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it "should not create custom table if expiry time is zero" do
        post :create, params: { name: 'Sample Custom Table', is_approval_required: true, approval_expiry_time: 0 }, as: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it 'should not create custom table if approval ids are less than 1' do
        post :create, params: { name: 'Sample Custom Table', is_approval_required: true, approval_expiry_time: 7, approval_type: 'person' }, as: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it 'should not create custom table if approval ids are greater than 1' do
        post :create, params: { name: 'Sample Custom Table', is_approval_required: true, approval_expiry_time: 7, approval_type: 'person', approval_ids: [1, 2, 3] }, as: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it 'should not create custom table if approval ids are none' do
        post :create, params: { name: 'Sample Custom Table', is_approval_required: true, approval_expiry_time: 7, approval_type: 'manager', approval_ids: [] }, as: :json
        expect(response.message).to eq('Unprocessable Entity')
      end

      it 'should not create custom table if approval ids are none' do
        post :create, params: { name: 'Sample Custom Table', is_approval_required: true, approval_expiry_time: 7, approval_type: 'permission', approval_ids: [] }, as: :json
        expect(response.message).to eq('Unprocessable Entity')
      end
    end

    context 'should create custom table' do
      context 'should create timeline non approval custom table' do
        before do
          post :create, params: { name: 'Sample Custom Table', table_type: CustomTable.table_types[:timeline] }, as: :json
        end

        it 'should return created message and create effective date custom field' do
          expect(response.message).to eq('Created')
          expect(JSON.parse(response.body)["custom_fields"].select {|table| table["name"]=="Effective Date"}.empty?).to eq(false)
        end
      end

      context 'should create timeline approval custom table' do
        before do
          post :create, params: { name: 'Sample Custom Table', table_type: CustomTable.table_types[:timeline], is_approval_required: true, approval_expiry_time: 7, approval_chains: [{ approval_type: 'manager', approval_ids: ['1']}] }, as: :json
        end

        it 'should return created message and create effective date custom field' do
          expect(response.message).to eq('Created')
          expect(JSON.parse(response.body)["custom_fields"].select {|table| table["name"]=="Effective Date"}.empty?).to eq(false)
        end
      end

      context 'should create standard non approval custom table' do
        before do
          post :create, params: { name: 'Sample Custom Table', table_type: CustomTable.table_types[:standard] }, as: :json
        end

        it "should create standard non approval custom table and not create effective date custom field" do
          expect(response.message).to eq('Created')
          expect(JSON.parse(response.body)["custom_fields"].select {|table| table["name"]=="Effective Date"}.empty?).to eq(true)
        end
      end
    end

    context 'employee should not have access to create custom table' do
      it 'should return 403 error' do
        allow(controller).to receive(:current_user).and_return(employee)

        post :create, params: { name: 'Sample Custom Table', table_type: CustomTable.table_types[:standard] }, as: :json
        expect(response.status).to eq(403)
      end
    end

    context 'manager should not have access to create custom table' do
      it 'should return 403 error' do
        allow(controller).to receive(:current_user).and_return(manager)

        post :create, params: { name: 'Sample Custom Table', table_type: CustomTable.table_types[:standard] }, as: :json
        expect(response.status).to eq(403)
      end
    end

    context 'admin or account owner should have access to create custom table' do
      it 'should allow admin to create table' do
        allow(controller).to receive(:current_user).and_return(admin)

        post :create, params: { name: 'Sample Custom Table', table_type: CustomTable.table_types[:standard] }, as: :json
        expect(response.message).to eq('Created')
      end

      it 'should allow super admin to create table' do
        allow(controller).to receive(:current_user).and_return(super_admin)

        post :create, params: { name: 'Sample Custom Table', table_type: CustomTable.table_types[:standard] }, as: :json
        expect(response.message).to eq('Created')
      end
    end
  end

  describe 'PUT #Update' do

    context 'should update custom table' do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
        put :update, params: { id: custom_table.id, name: 'Name Updated', table_type: CustomTable.table_types[:standard] }, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status, update name, update table type, keys count of custom table, valid keys of custom table, keys count of custom field, valid keys of custom fields" do
        expect(response.status).to eq(200)
        expect(@result['name']).to eq('Name Updated')
        expect(@result['table_type']).to eq('standard')
        expect(@result.keys.count).to eq(13)
        expect(@result.keys).to eq(["id", "name", "table_type", "custom_table_property", "position", "is_approval_required", "approval_type", "approval_ids", "approval_expiry_time", "approve_by_user", "approval_chains", "used_in_templates_count", "custom_fields"])
        expect(@result["custom_fields"][0].keys.count).to eq(26)
        expect(@result["custom_fields"][0].keys).to eq(["id", "section", "position", "name", "help_text", "default_value", "field_type", "required", "required_existing", "collect_from", "api_field_id", "custom_table_id", "custom_table_property", "profile_setup", "display_location", "is_sensitive_field", "lever_requisition_field_id", "used_in_templates", "custom_field_options", "locks", "sub_custom_fields", "ats_mapping_key", "ats_mapping_section", "ats_mapping_field_type", "workday_mapping_key", "is_group_type_field"])
      end
    end

    context 'should allow admin to update custom table' do
      it 'should allow admin to update table' do
        allow(controller).to receive(:current_user).and_return(admin)

        put :update, params: { id: custom_table.id, name: 'Name Updated', table_type: CustomTable.table_types[:timeline], approval_chains_attributes: [{ approval_type: 'manager', approval_ids: ['1']}] }, as: :json
        expect(response.status).to eq(200)
      end
    end

    context 'should not update custom table' do
      context "should not update custom table of other company" do
        let(:other_company) { create(:company, subdomain: 'boo') }
        let(:other_custom_table) { create(:custom_table, company: other_company) }

        before do
          allow(controller).to receive(:current_user).and_return(super_admin)
          put :update, params: { id: other_custom_table.id, name: 'Name Updated', table_type: CustomTable.table_types[:timeline], approval_chains_attributes: [{ approval_type: 'manager', approval_ids: ['1']}] }, as: :json
        end

        it "should return forbidden status" do
          expect(response.status).to eq(403)
        end
      end

      context "should not update custom table for unauthenticated user" do
        before do
          allow(controller).to receive(:current_user).and_return(nil)
          put :update, params: { id: custom_table.id, name: 'Name Updated', table_type: CustomTable.table_types[:timeline], approval_chains_attributes: [{ approval_type: 'manager', approval_ids: ['1']}] }, as: :json
        end

        it "should return unauthorized status" do
         expect(response.status).to eq(401)
        end
      end

      context "employee should not have access to update custom table" do
        before do
          allow(controller).to receive(:current_user).and_return(employee)
          put :update, params: { id: custom_table.id, name: 'Name Updated', table_type: CustomTable.table_types[:timeline], approval_chains_attributes: [{ approval_type: 'manager', approval_ids: ['1']}] }, as: :json
        end

        it "should return forbidden status" do
         expect(response.status).to eq(403)
        end
      end

      context "manager should not have access to update custom table" do
        before do
          allow(controller).to receive(:current_user).and_return(manager)
          put :update, params: { id: custom_table.id, name: 'Name Updated', table_type: CustomTable.table_types[:timeline], approval_chains_attributes: [{ approval_type: 'manager', approval_ids: ['1']}] }, as: :json
        end

        it "should return forbidden status" do
         expect(response.status).to eq(403)
        end
      end
    end
  end

  describe "DELETE #destroy" do
    before do
      allow(controller).to receive(:current_user).and_return(super_admin)
    end

    context "should delete custom table" do
      it "should return no content status and return only default custom table" do
        delete :destroy, params: { id: custom_table.id }, as: :json
        expect(response.status).to eq(204)
        expect(company.custom_tables.count).to eq(3)
      end
    end

    context 'should allow admin to destroy custom table' do
      it 'should allow admin to destroy table' do
        allow(controller).to receive(:current_user).and_return(admin)

        delete :destroy, params: { id: custom_table.id }, as: :json
        expect(response.status).to eq(204)
      end
    end

    context "should not delete custom table of other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:other_custom_table) { create(:custom_table, company: other_company) }

      it "should return forbidden status" do
        delete :destroy, params: { id: other_custom_table.id }, as: :json
        expect(response.status).to eq(403)
      end
    end

    context "should not delete custom table" do
      it "should return unauthorized status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        delete :destroy, params: { id: custom_table.id }, as: :json
        expect(response.status).to eq(401)
      end

      it "should return forbidden status for employee" do
        allow(controller).to receive(:current_user).and_return(employee)
        delete :destroy, params: { id: custom_table.id }, as: :json
        expect(response.status).to eq(403)
      end

      it "should return forbidden status for manager" do
        allow(controller).to receive(:current_user).and_return(manager)
        delete :destroy, params: { id: custom_table.id }, as: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe 'GET #custom tables bulk operation' do
    context "should get custom table for bulk operation" do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
        get :custom_tables_bulk_operation, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status and 4 keys of custom table and valid keys of custom table" do
        expect(response.status).to eq(200)
      end
    end

    context "should not return custom table for unauthenticated user" do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        get :custom_tables_bulk_operation, as: :json
      end

      it "should return unauthorised status" do
        expect(response.status).to eq(401)
      end
    end

    context "should not return custom table for other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:other_user) { create(:user, company: other_company) }

      it 'should return forbidden status' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :custom_tables_bulk_operation, as: :json
        expect(response.status).to eq(403)
      end
    end

    context 'admins should have access to get custom table for bulk operation' do
      before do
        allow(controller).to receive(:current_user).and_return(admin)
      end

      it 'should return 200 status' do
        get :custom_tables_bulk_operation, as: :json
        expect(response.status).to eq(200)
      end
    end

   context 'super admins should have access to get custom table for bulk operation' do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
      end

      it 'should return 200 status' do
        get :custom_tables_bulk_operation, as: :json
        expect(response.status).to eq(200)
      end
    end

    context 'employee should not have access to get custom table for bulk operation' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end

      it 'should return 403 status' do
        get :custom_tables_bulk_operation, as: :json
        expect(response.status).to eq(403)
      end
    end

    context 'manager should not have access to get custom table for bulk operation' do
      before do
        allow(controller).to receive(:current_user).and_return(manager)
      end

      it 'should return 403 status' do
        get :custom_tables_bulk_operation, as: :json
        expect(response.status).to eq(403)
      end
    end
  end

  describe 'GET #custom table columns' do
    context 'should get custom columns of employment status table' do
      before do
        custom_table = CustomTable.where(custom_table_property: CustomTable.custom_table_properties[:employment_status]).first
        allow(controller).to receive(:current_user).and_return(admin)
        get :custom_table_columns, params: { id: custom_table.id }, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status and 2 keys of custom table, valid keys of custom table, 6 keys of custom field, valid keys of custom fields, 7 keys of preference fields and valid keys of preference fields" do
        expect(response.status).to eq(200)
        expect(@result.keys.count).to eq(2)
        expect(@result.keys).to eq(["custom_fields", "preference_fields"])
        expect(@result["custom_fields"][0].keys.count).to eq(9)
        expect(@result["custom_fields"][0].keys).to eq(["id", "name", "field_type", "position", "custom_field_options", "sub_custom_fields", "is_sensitive_field", "help_text", "default_value"])
        expect(@result["preference_fields"][0].keys.count).to eq(22)
        expect(@result["preference_fields"][0].keys).to eq(["id", "name", "api_field_id", "section", "position", "isDefault", "editable", "enabled", "field_type", "collect_from", "can_be_collected", "visibility", "is_editable", "custom_table_property", "profile_setup", "deletable", "is_sensitive_field", "ats_mapping_section", "ats_integration_group", "ats_mapping_field_type", "ats_mapping_key", "custom_section_id"])
      end
    end

    context 'employee should not get custom table columns' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
        custom_table = CustomTable.where(custom_table_property: CustomTable.custom_table_properties[:employment_status]).first
        get :custom_table_columns, params: { id: custom_table.id }, as: :json
      end

      it 'should return forbidden status' do
        expect(response.status).to eq(403)
      end
    end

    context 'manager should not get custom table columns' do
      before do
        allow(controller).to receive(:current_user).and_return(manager)
        custom_table = CustomTable.where(custom_table_property: CustomTable.custom_table_properties[:employment_status]).first
        get :custom_table_columns, params: { id: custom_table.id }, as: :json
      end

      it 'should return forbidden status' do
        expect(response.status).to eq(403)
      end
    end

    context "should not return custom table for unauthenticated user" do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        get :custom_table_columns, params: { id: custom_table.id }, as: :json
      end

      it "should return unauthorised status" do
        expect(response.status).to eq(401)
      end
    end

    context "should not return custom table for other company" do
      let(:other_company) { create(:company, subdomain: 'boo') }
      let(:other_user) { create(:user, company: other_company) }
      let(:other_custom_table) { create(:custom_table, company: other_company) }

      it 'should return forbidden status' do
        allow(controller).to receive(:current_user).and_return(admin)
        get :custom_tables_bulk_operation, params: { id: other_custom_table.id }, as: :json
        expect(response.status).to eq(403)
      end

      it 'should return forbidden status' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :custom_tables_bulk_operation, params: { id: custom_table.id }, as: :json
        expect(response.status).to eq(403)
      end
    end
  end
  
  describe 'GET #index' do
    context "should show custom table for index" do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
        get :index, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status" do
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'GET #home_index' do
    context "should show custom table for home index" do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
        get :home_index, params: {user_id: super_admin.id}, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status" do
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'GET #bulk_onboarding_index' do
    context "should show custom table for bulk onboarding index" do
      before do
        allow(controller).to receive(:current_user).and_return(super_admin)
        get :bulk_onboarding_index, as: :json
        @result = JSON.parse(response.body)
      end

      it "should return 200 status" do
        expect(response.status).to eq(200)
      end
    end
  end
end