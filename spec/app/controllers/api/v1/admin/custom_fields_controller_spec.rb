require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Api::V1::Admin::CustomFieldsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:mobile_phone_field) { create(:mobile_phone_number_field, company: company) }
  let(:gender) { create(:custom_field, name: 'Gender A', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:manager) { create(:nick, company: company) }
  let(:employee){ create(:user, role: :employee, company: company) }
  let(:admin_user) { create(:user, state: :active, current_stage: :registered, company: company, role: :admin) }
  let(:other_company) {create(:company)}
  let(:admin_user_with_other_company) { create(:user, state: :active, current_stage: :registered, company: other_company, role: :admin) }
  let(:other_user) { create(:user, company: other_company) }
  let(:employment_status) { company.custom_fields.find_by(field_type: 13) }
  let(:custom_field_of_other_company) { create(:custom_field, name: 'Gender A', section: 'personal_info', field_type: 'mcq', company: other_company) }
  subject(:admin_user_ability) { Ability.new(admin_user) }
  subject(:user_ability) { Ability.new(admin_user) }
  subject(:manager_ability) { Ability.new(manager) }
  subject(:employee_ability) { Ability.new(employee) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "POST #create" do

    context 'Any User without logging in' do
      it 'should not be able to create custom field' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { name: 'Gender A', section: 'personal_info', field_type: 'mcq' }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it { user_ability.should be_able_to(:create, gender)}

      it "should create custom field of MCQ type without options" do
        post :create, params: { name: 'Gender A', section: 'personal_info', field_type: 'mcq' }, format: :json
        expect(response.message).to eq('Created')
      end

      it "should create custom field of MCQ type with options" do
        post :create, params: { name: 'Gender A', section: 'personal_info', field_type: 'mcq', custom_field_options:
          [{ option: 'Male' }, { option: 'Female', position: 1 }, { option: 'Other', position: 2 }] },
          format: :json
        expect(response.message).to eq('Created')
      end

      it "should not be able to create custom field of another company" do
        allow(controller).to receive(:current_user).and_return(other_user)
        post :create, params: { name: 'Gender A', company: other_company, section: 'personal_info', field_type: 'mcq', custom_field_options:
          [{ option: 'Male' }, { option: 'Female', position: 1 }, { option: 'Other', position: 2 }] },
          format: :json
        expect(response).to have_http_status(403)
      end
    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it { admin_user_ability.should be_able_to(:create, gender)}

      it "should be able to create custom field" do
        allow(controller).to receive(:current_user).and_return(admin_user)
        post :create, params: { name: 'Gender A', section: 'personal_info', field_type: 'mcq' }, format: :json
        expect(response.message).to eq('Created')
      end

      it "should not be able to create custom field of another company" do
        allow(controller).to receive(:current_user).and_return(admin_user_with_other_company)
        post :create, params: { name: 'Gender A', company: other_company, section: 'personal_info', field_type: 'mcq' }, format: :json
        expect(response).to have_http_status(403)
      end
    end

    context 'Manager' do
      it { manager_ability.should_not be_able_to(:create, gender)}

      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it "should not be able to create custom field" do
        post :create, params: { name: 'Gender A', section: 'personal_info', field_type: 'mcq' }, format: :json
        expect(response.message).to eq('Forbidden')
        expect(response).to have_http_status(403)
      end

      it "should not be able to create custom field of another company" do
        post :create, params: { name: 'Gender A', company: other_company, section: 'personal_info', field_type: 'mcq' }, format: :json
        expect(response.message).to eq('Forbidden')
        expect(response).to have_http_status(403)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it { employee_ability.should_not be_able_to(:create, gender)}

      it "should not be able to create custom field" do
        post :create, params: { name: 'Gender A', section: 'personal_info', field_type: 'mcq' }, format: :json
        expect(response.message).to eq('Forbidden')
        expect(response).to have_http_status(403)
      end

      it "should not be able to create custom field of another company" do
        post :create, params: { name: 'Gender A', company: other_company, section: 'personal_info', field_type: 'mcq', company: other_company }, format: :json
        expect(response.message).to eq('Forbidden')
        expect(response).to have_http_status(403)
      end
    end
  end

  describe "#index" do

    context 'Any User without logging in' do
      it 'should not be allowed to access custom fields' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it { user_ability.should be_able_to(:read, gender)}

      it 'should be allowed to access custom fields' do
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        custom_field = json.first
        expect(custom_field['field_type']).to eq('employment_status')
      end

      it 'should not be allowed to access custom fields of other company' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it { admin_user_ability.should be_able_to(:read, gender)}

      it 'should not be allowed to access custom fields of other company' do
        allow(controller).to receive(:current_user).and_return(admin_user_with_other_company)
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should be allowed to access custom fields with view and edit access permission' do
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        custom_field = json.first
        expect(custom_field['field_type']).to eq('employment_status')
      end

      it 'should be allowed to access custom fields with view only access permission' do
        admin_user.user_role.permissions['admin_visibility']['groups'] = 'view_only'
        admin_user.save
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        json = JSON.parse(response.body)
        expect(response).to have_http_status(200)
        custom_field = json.first
        expect(custom_field['field_type']).to eq('employment_status')
      end

      it 'should not be allowed to access custom fields with no access permission' do
        admin_user.user_role.permissions['admin_visibility']['groups'] = 'no_access'
        admin_user.save
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it { manager_ability.should be_able_to(:read, gender)}

      it 'should not be allowed to access custom fields of other company' do
        manager.company = other_company
        manager.save
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access custom fields' do
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it 'should not be allowed to access custom fields inside group tab' do
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access custom fields inside group tab of another company with field type' do
        employee.company = other_company
        employee.save
        get :index, params: { field_type: 13, sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access custom fields inside group tab of another company without field type' do
        employee.company = other_company
        employee.save
        get :index, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end
    end
  end

  describe "#onboarding_page_index" do
    context 'Any User without logging in' do
      it 'should not be allowed to access onboarding page custom fields' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it 'should be allowed to access onboarding page custom fields' do
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json = json['new_hire']['profile_fields']
        json.each { |custom_field| expect(custom_field['display_location']).to eq(0).or be_nil }
      end

      it 'should not be allowed to access onboarding page custom fields of another company' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it 'should not be allowed to access onboarding page custom fields of another company' do
        allow(controller).to receive(:current_user).and_return(admin_user_with_other_company)
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should be allowed to access onboarding page custom fields with view and edit access permission' do
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json = json['new_hire']['profile_fields']
        json.each { |custom_field| expect(custom_field['display_location']).to eq(0).or be_nil }
      end

      it 'should not be allowed to access onboarding page custom fields with view only access permission' do
        admin_user.user_role.permissions['admin_visibility']['dashboard'] = 'view_only'
        admin_user.save
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access onboarding page custom fields with no access permission' do
        admin_user.user_role.permissions['admin_visibility']['dashboard'] = 'no_access'
        admin_user.save
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it 'should not be allowed to access custom fields' do
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access custom fields of another company' do
        manager.company = other_company
        manager.save
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it 'should not be allowed to access custom fields' do
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access custom fields' do
        employee.company = other_company
        employee.save
        get :onboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end
  end

  describe "#request_info_index" do
    context 'User Without Logging In' do
      it 'should not be allowed to access Request Info Modal custom fields' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :request_info_index, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it 'should be allowed to access Request Info Modal custom fields' do
        get :request_info_index, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json).to eq(company.custom_fields.where(custom_table_id: nil).as_json(only: [:id, :name]))
      end

      it 'should not be allowed to access Request Info Modal custom fields of another company' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :request_info_index, format: :json
        expect(response).to have_http_status(403)
      end
    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it 'should be allowed to access Request Info Modal custom fields' do
        get :request_info_index, format: :json
        json = JSON.parse(response.body)
        expect(response).to have_http_status(200)
        expect(json).to eq(company.custom_fields.where(custom_table_id: nil).as_json(only: [:id, :name]))
      end

      it 'should not be allowed to access Request Info Modal custom fields of another company' do
        allow(controller).to receive(:current_user).and_return(admin_user_with_other_company)
        get :request_info_index, format: :json
        expect(response).to have_http_status(403)
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it 'should not be allowed to access Request Info Modal custom fields' do
        get :request_info_index, format: :json
        expect(response).to have_http_status(403)
      end

      it 'should not be allowed to access Request Info Modal custom fields of another company' do
        manager.company = other_company
        manager.save
        get :request_info_index, format: :json
        expect(response).to have_http_status(403)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it 'should not be allowed to access Request Info Modal custom fields' do
        get :request_info_index, format: :json
        expect(response).to have_http_status(403)
      end

      it 'should not be allowed to access Request Info Modal custom fields of another company' do
        employee.company = other_company
        employee.save
        get :request_info_index, format: :json
        expect(response).to have_http_status(403)
      end
    end
  end

  describe "#onboarding_info_fields" do
    context 'User Without Logging In' do
      it 'should not be allowed to access onboarding info custom fields' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it 'should be allowed to access onboarding info custom fields' do
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json.each { |custom_field| expect(custom_field['custom_table_property']).to eq('employment_status') }
      end

      it 'should not be allowed to access onboarding info custom fields of another company' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it 'should not be allowed to access onboarding info custom fields with view and edit permission' do
        allow(controller).to receive(:current_user).and_return(admin_user_with_other_company)
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should be allowed to access onboarding info custom fields with view and edit permission' do
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        json = JSON.parse(response.body)
        expect(response).to have_http_status(200)
        json.each { |custom_field| expect(custom_field['custom_table_property']).to eq('employment_status') }
      end

      it 'should not be allowed to access onboarding info custom fields with view only permission' do
        admin_user.user_role.permissions['admin_visibility']['dashboard'] = 'view_only'
        admin_user.save
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access onboarding info custom fields with no access' do
        admin_user.user_role.permissions['admin_visibility']['dashboard'] = 'no_access'
        admin_user.save
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it 'should not be allowed to access onboarding info custom fields' do
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access onboarding info custom fields of another company' do
        manager.company = other_company
        manager.save
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it 'should not be allowed to onboarding info access custom fields' do
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to onboarding info access custom fields of another company' do
        employee.company = other_company
        employee.save
        get :onboarding_info_fields, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end
  end

  describe "#offboarding_page_index" do
    before do
      create(:custom_field, company: company, display_location: CustomField.display_locations[:offboarding])
    end
    context 'User Without Logging In' do
      it 'should not be allowed to access offboarding page custom fields' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it 'should be allowed to access offboarding page custom fields' do
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json.each { |custom_field| expect(custom_field['display_location']).to eq('offboarding').or eq(nil) }
      end

      it 'should not be allowed to access offboarding page custom fields of another company' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it 'should not be allowed to access offboarding page custom fields of another company' do
        allow(controller).to receive(:current_user).and_return(admin_user_with_other_company)
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should be allowed to access offboarding page custom fields with view_and_edit permission' do
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        json = JSON.parse(response.body)
        expect(response).to have_http_status(200)
        json.each { |custom_field| expect(custom_field['display_location']).to eq('offboarding').or eq(nil) }
      end

      it 'should not be allowed to access offboarding page custom fields with view_only permission' do
        admin_user.user_role.permissions['admin_visibility']['dashboard'] = 'view_only'
        admin_user.save
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access offboarding page custom fields with no access' do
        admin_user.user_role.permissions['admin_visibility']['dashboard'] = 'no_access'
        admin_user.save
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it 'should not be allowed to offboarding page custom fields' do
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to offboarding page custom fields of another company' do
        manager.company = other_company
        manager.save
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it 'should not be allowed to onboarding info access custom fields' do
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to onboarding info access custom fields of another company' do
        employee.company = other_company
        employee.save
        get :offboarding_page_index, params: { sub_tab: 'dashboard' }, format: :json
        expect(response).to have_http_status(204)
      end
    end
  end

  describe "#reporting_page_index" do
    context 'User Without Logging In' do
      it 'should not be allowed to access reporting page custom fields' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it 'should be allowed to access reporting page custom fields' do
        company.custom_fields.update_all(field_type: CustomField.field_types[:employment_status])
        company.reload
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json.each { |custom_field| expect(custom_field['field_type']).to eq('employment_status') }
      end

      it 'should not be allowed to access reporting page custom fields of another company' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
        company.custom_fields.update_all(field_type: CustomField.field_types[:employment_status])
        company.reload
      end
      it 'should not be allowed to access reporting page custom fields of another company' do
        allow(controller).to receive(:current_user).and_return(admin_user_with_other_company)
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should be allowed to access reporting page custom fields with view and edit access' do
        admin_user.user_role.permissions['admin_visibility']['reports'] = 'view_and_edit'
        admin_user.save
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json.each { |custom_field| expect(custom_field['field_type']).to eq('employment_status') }
      end

      it 'should be allowed to access reporting page custom fields with view only access' do
        admin_user.user_role.permissions['admin_visibility']['reports'] = 'view_only'
        admin_user.save
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json.each { |custom_field| expect(custom_field['field_type']).to eq('employment_status') }
      end

      it 'should not be allowed to access reporting page custom fields with no access' do
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it 'should not be allowed to access reporting page custom fields' do
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access reporting page custom fields of another company' do
        manager.company = other_company
        manager.save
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it 'should not be allowed to access reporting page custom fields' do
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access reporting page custom fields of another company' do
        employee.company = other_company
        employee.save
        get :reporting_page_index, params: { sub_tab: 'reports' }, format: :json
        expect(response).to have_http_status(204)
      end
    end
  end

  describe "#employment_status_fields" do
    context 'User Without Logging In' do
      it 'should not be allowed to access employment status fields' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :employment_status_fields, params: { field_type: 13 }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it 'should be allowed to access employment status fields' do
        get :employment_status_fields, params: { sub_tab: 'integrations', field_type: 13 }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json.each { |custom_field| expect(custom_field['field_type']).to eq('employment_status') }
      end

      it 'should not be allowed to access employment status fields of another company' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :employment_status_fields, params: { sub_tab: 'integrations', field_type: 13 }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it 'should not be allowed to access employment status fields of another company' do
        allow(controller).to receive(:current_user).and_return(admin_user_with_other_company)
        get :employment_status_fields, params: { sub_tab: 'integrations', field_type: 13 }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access employment status fields with view no access' do
        get :employment_status_fields, params: { sub_tab: 'integrations', field_type: 13 }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should be allowed to access employment status fields with view and edit access' do
        admin_user.user_role.permissions['admin_visibility']['integrations'] = 'view_and_edit'
        admin_user.save
        get :employment_status_fields, params: { sub_tab: 'integrations', field_type: 13 }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json.each { |custom_field| expect(custom_field['field_type']).to eq('employment_status') }
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it 'should not be allowed to access employment status fields' do
        get :employment_status_fields, params: { sub_tab: 'integrations', field_type: 13 }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access employment status fields of another company' do
        manager.company = other_company
        manager.save
        get :employment_status_fields, params: { sub_tab: 'integrations', field_type: 13 }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it 'should not be allowed to access employment status fields' do
        get :employment_status_fields, params: { sub_tab: 'integrations', field_type: 13 }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access employment status fields of another company' do
        employee.company = other_company
        employee.save
        get :employment_status_fields, params: { sub_tab: 'integrations', field_type: 13 }, format: :json
        expect(response).to have_http_status(204)
      end
    end
  end

  describe "#custom_groups" do
    before do
      create(:custom_field, integration_group: CustomField.integration_groups[:namely], company: company)
    end
    context 'User Without Logging In' do
      it 'should not be allowed to access custom group fields' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :custom_groups, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it 'should be allowed to access custom group fields' do
        get :custom_groups, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json.each { |custom_field| expect(custom_field['integration_group']).not_to eq('no_integration') }
      end

      it 'should not be allowed to access custom group fields of another company' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :custom_groups, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it 'should not be allowed to access custom group fields of another company' do
        allow(controller).to receive(:current_user).and_return(admin_user_with_other_company)
        get :custom_groups, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access custom group fields with view no access' do
        admin_user.user_role.permissions['admin_visibility']['groups'] = 'no_access'
        admin_user.save
        get :custom_groups, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should be allowed to access custom group fields with view and edit access' do
        get :custom_groups, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        json.each { |custom_field| expect(custom_field['integration_group']).not_to eq('no_integration') }
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it 'should not be allowed to access custom group fields' do
        get :custom_groups, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access custom group fields of another company' do
        manager.company = other_company
        manager.save
        get :custom_groups, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it 'should not be allowed to access custom group fields' do
        get :custom_groups, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be allowed to access custom group fields of another company' do
        employee.company = other_company
        employee.save
        get :custom_groups, params: { sub_tab: 'groups' }, format: :json
        expect(response).to have_http_status(204)
      end
    end
  end

  describe "#export_employee_record" do
    context 'User Without Logging In' do
      it 'should not be allowed to export own record' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :export_employee_record, params: { user_id: user.id }, format: :json
        expect(response).to have_http_status(401)
      end

      it 'should not be allowed to export any other employee record' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :export_employee_record, params: { user_id: employee.id }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it 'should be allowed to export own record' do
        get :export_employee_record, params: { user_id: user.id }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json['id']).to eq(user.id)
        expect(json['first_name']).to eq(user.first_name)
        expect(json['last_name']).to eq(user.last_name)
      end

      it 'should not be allowed to export other company employee record' do
        get :export_employee_record, params: { user_id: other_user.id }, format: :json
        expect(response).to have_http_status(403)
      end
    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it 'should be allowed to export own record' do
        get :export_employee_record, params: { user_id: admin_user.id }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json['id']).to eq(admin_user.id)
        expect(json['first_name']).to eq(admin_user.first_name)
        expect(json['last_name']).to eq(admin_user.last_name)
      end

      it 'should not be allowed to export other company employee record' do
        get :export_employee_record, params: { user_id: other_user.id }, format: :json
        expect(response).to have_http_status(403)
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it 'should be allowed to export own record' do
        get :export_employee_record, params: { user_id: manager.id }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json['id']).to eq(manager.id)
        expect(json['first_name']).to eq(manager.first_name)
        expect(json['last_name']).to eq(manager.last_name)
      end

      it 'should not be allowed to export other company employee record' do
        get :export_employee_record, params: { user_id: other_user.id }, format: :json
        expect(response).to have_http_status(403)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it 'should be allowed to export own record' do
        get :export_employee_record, params: { user_id: employee.id }, format: :json
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json['id']).to eq(employee.id)
        expect(json['first_name']).to eq(employee.first_name)
        expect(json['last_name']).to eq(employee.last_name)
      end

      it 'should not be allowed to export other company employee record' do
        get :export_employee_record, params: { user_id: other_user.id }, format: :json
        expect(response).to have_http_status(403)
      end
    end
  end

  describe "#update" do
    it "should update custom field of MCQ type by adding option" do
      post :update, params: { id: gender.id, custom_field_options: [{ option: 'Male' },
        { option: 'Female', position: 1 }, { option: 'Other', position: 2 }] }, format: :json
      gender.reload
      expect(gender.custom_field_options.count).to eq(3)
    end

    it "should update custom field of MCQ type by destroying option" do
      post :update, params: { id: gender.id, custom_field_options: [{ option: 'Male' },
        { option: 'Female', position: 1 }, { option: 'Other', position: 2, _destroy: true }] }, format: :json
      gender.reload
      expect(gender.custom_field_options.count).to eq(2)
    end

    context 'updating custom_field with sub_custom_fields' do
      let(:nick){ create(:nick, company: company) }
      let!(:custom_field){ create(:address_with_multiple_sub_custom_fields, company: company) }
      before do
        first_sub_custom_field_id = custom_field.sub_custom_fields.order('id asc').first.id
        @params = {id: "#{custom_field.id}", section: "private_info", position: 3, name: "Home Address",
          help_text: nil, field_type: "address", required: true, required_existing: nil, collect_from: "new_hire",
          custom_table_id: nil, custom_table_property: nil, profile_setup: "profile_fields",
          display_location: nil, is_sensitive_field: false, custom_field_options: nil,
          locks: {all_locks: false}, integration_group: "no_integration", ats_mapping_key: nil, ats_mapping_section: nil,
          ats_mapping_field_type: nil, workday_mapping_key: nil, sub_custom_fields: [{id: "#{first_sub_custom_field_id}", name: "Line 1", field_type: "short_text",
          help_text: "Line 1"}, {id: "#{first_sub_custom_field_id + 1}", name: "Line 2", field_type: "short_text", help_text: "Line 2"},
          {id: "#{first_sub_custom_field_id + 2}", name: "City", field_type: "short_text", help_text: "City"},
          {id: "#{first_sub_custom_field_id + 3}", name: "Country", field_type: "short_text", help_text: "Country",
          custom_field_value: {value_text: "United States"}}, {id: "#{first_sub_custom_field_id + 4}", name: "State", field_type: "short_text", help_text: "State"},
          {id: "#{first_sub_custom_field_id + 5}", name: "Zip", field_type: "short_text", help_text: "Zip/ Post Code"}], visibility: true, user_id: "#{nick.id}", skip_validations: true, format: :json}
      end
      context 'creating user_address (cfv with sub_custom_fields)' do
        before do
          put :update, params: @params
        end

        it 'should set default value for country' do
          sub_field = custom_field.sub_custom_fields.find_by_name("Country")
          expect(nick.reload.custom_field_values.find_by_sub_custom_field_id(sub_field.id).value_text).to eq("United States")
        end

        it 'should create custom_field_values for each sub_custom_field' do
          expect(CustomFieldValue.count).to eq(6)
        end
      end
      context 'creating user_address with additional information' do
        before do
          @params[:sub_custom_fields][0][:custom_field_value] = {value_text: 'Line 1 of address'}
          @params[:sub_custom_fields][1][:custom_field_value] = {value_text: 'Line 2 of address'}
          @params[:sub_custom_fields][2][:custom_field_value] = {value_text: 'NewYork'}
          put :update, params: @params
        end
        it 'should update address line1 in cfv' do
          sub_custom_field = custom_field.sub_custom_fields.find_by_name('Line 1')
          expect(nick.reload.custom_field_values.find_by_sub_custom_field_id(sub_custom_field.id).value_text)
          .to eq('Line 1 of address')
        end
        it 'should update address line2 in cfv' do
          sub_custom_field = custom_field.sub_custom_fields.find_by_name('Line 2')
          expect(nick.reload.custom_field_values.find_by_sub_custom_field_id(sub_custom_field.id).value_text)
          .to eq('Line 2 of address')
        end
      end
    end

    context 'updating mobile phone number' do
      before do
        @nick = FactoryGirl.create(:nick, company_id: company.id)
        @sarah = FactoryGirl.create(:sarah, company_id: company.id)
        User.current = @sarah
      end
      it 'creates field history for changer and auditable of same company' do
        sub_custom_fields = mobile_phone_field.sub_custom_fields
        response = put :update, params: { id: "#{mobile_phone_field.id}", section: "private_info", position: mobile_phone_field.position, name: "#{mobile_phone_field.name}", field_type: "#{mobile_phone_field.field_type}", required: true, collect_from: "new_hire", custom_field_options: nil, skip_validations: true, "sub_custom_fields"=>[{"id"=>"#{sub_custom_fields[0].id}", "name"=>"#{sub_custom_fields[0].name}", "field_type"=>"#{sub_custom_fields[0].field_type}", "help_text"=>"Country", "custom_field_value"=>{"value_text"=>"AUS"}}, {"id"=>"#{sub_custom_fields[1].id}", "name"=>"#{sub_custom_fields[1].name}", "field_type"=>"#{sub_custom_fields[1].field_type}", "help_text"=>"Area code", "custom_field_value"=>{"value_text"=>"32130"}}, {"id"=>"#{sub_custom_fields[2].id}", "name"=>"#{sub_custom_fields[2].name}", "field_type"=>"#{sub_custom_fields[2].field_type}", "help_text"=>"Phone", "custom_field_value"=>{"value_text"=>"1231212812"}}], user_id: "#{@nick.id}" }, format: :json
        expect(FieldHistory.all.size).to eq(1)
        expect(FieldHistory.first.new_value).to eq("AUS, 32130, 1231212812")
        expect(FieldHistory.first.field_auditable.company_id).to eq(company.id)
        expect(FieldHistory.first.field_changer.company_id).to eq(company.id)
      end
    end

    context 'User Without Logging In' do
      it 'should not be allowed to update custom field' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :update, params: { id: gender.id, custom_field_options: [{ option: 'Male' },{ option: 'Female', position: 1 }, { option: 'Other', position: 2 }] }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'Super Admin' do
      it{ user_ability.should be_able_to(:manage, gender) }

      it 'should be able to update custom field of employee of same company' do
        post :update, params: { id: gender.id, user_id: employee.id, custom_field_options: [{ option: 'Male' },{ option: 'Female', position: 1 }, { option: 'Other', position: 2 }] }, format: :json
        gender.reload
        expect(gender.custom_field_options.count).to eq(3)
      end

      it 'should not be able to update custom field of employee of other company' do
        post :update, params: { id: custom_field_of_other_company.id, user_id: other_user.id, custom_field_options: [{ option: 'Male' },{ option: 'Female', position: 1 }, { option: 'Other', position: 2 }] }, format: :json
        expect(response).to have_http_status(403)
      end
    end


    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it{ admin_user_ability.should be_able_to(:manage, gender) }

      it 'should not be able to update custom field of employee of other company' do
        post :update, params: { id: custom_field_of_other_company.id, user_id: other_user.id, custom_field_options: [{ option: 'Male' },{ option: 'Female', position: 1 }, { option: 'Other', position: 2 }] }, format: :json
        expect(response).to have_http_status(403)
      end

      it 'should be able to update custom field of employee of same company' do
        post :update, params: { id: gender.id, user_id: employee.id, custom_field_options: [{ option: 'Male' },{ option: 'Female', position: 1 }, { option: 'Other', position: 2 }] }, format: :json
        gender.reload
        expect(gender.custom_field_options.count).to eq(3)
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it{ manager_ability.should_not be_able_to(:manage, gender) }

      it 'should be able to update custom field of employee whose manager is current user and is of same company with access permission of view_and_edit' do
        post :update, params: { id: gender.id, user_id: employee.id, custom_field_options: [{ option: 'Male' },{ option: 'Female', position: 1 }, { option: 'Other', position: 2 }] }, format: :json
        gender.reload
        expect(gender.custom_field_options.count).to eq(3)
      end

      it 'should not be able to update custom field of employee of other company' do
        post :update, params: { id: custom_field_of_other_company.id, user_id: other_user.id, custom_field_options: [{ option: 'Male' },{ option: 'Female', position: 1 }, { option: 'Other', position: 2 }] }, format: :json
        expect(response).to have_http_status(403)
      end
    end
  end

  describe "#destroy" do
    context 'User Without Logging In' do
      it 'should not be allowed to delete custom field' do
        allow(controller).to receive(:current_user).and_return(nil)
        Sidekiq::Testing.inline! do
          delete :destroy, params: { id: gender.id }, format: :json
          expect(response).to have_http_status(401)
        end
      end
    end

    context 'Super Admin' do
      it{ user_ability.should be_able_to(:destroy, gender) }

      it 'should be able to destroy custom field of same company' do
        delete :destroy, params: { id: gender.id }, format: :json
        expect(response).to have_http_status(204)
      end

      it 'should not be able to destroy custom field of other company' do
        delete :destroy, params: { id: custom_field_of_other_company.id }, format: :json
        expect(response).to have_http_status(403)
      end

    end

    context 'Admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
      end
      it{ admin_user_ability.should be_able_to(:destroy, gender) }

      it 'should be able to destroy custom field of same company' do
        delete :destroy, params: { id: gender.id }, format: :json
        expect(response).to have_http_status(204)
        expect(CustomField.find_by_id(gender.id)).to be_nil
      end

      it 'should be able to update custom field of other company' do
        delete :destroy, params: { id: custom_field_of_other_company.id }, format: :json
        expect(response).to have_http_status(403)
      end
    end

    context 'Manager' do
      before do
        employee.update(manager_id: manager.id)
        manager.update(user_role_id: nil)
        allow(controller).to receive(:current_user).and_return(manager)
      end
      it{ manager_ability.should_not be_able_to(:destroy, gender) }

      it 'should not be able to destroy custom field of same company' do
        delete :destroy, params: { id: gender.id }, format: :json
        expect(response).to have_http_status(403)
      end

      it 'should not be able to destroy custom field of other company' do
        manager.company = other_company
        manager.save
        delete :destroy, params: { id: gender.id }, format: :json
        expect(response).to have_http_status(403)
      end
    end

    context 'Employee' do
      before do
        allow(controller).to receive(:current_user).and_return(employee)
      end
      it{ employee_ability.should_not be_able_to(:destroy, gender) }

      it 'should not be able to destroy custom field of same company' do
        delete :destroy, params: { id: gender.id }, format: :json
        expect(response).to have_http_status(403)
      end

      it 'should not be able to destroy custom field of other company' do
        employee.company = other_company
        employee.save
        delete :destroy, params: { id: custom_field_of_other_company.id }, format: :json
        expect(response).to have_http_status(403)
      end
    end
  end

  describe '#delete_sub_custom_fields' do
    let(:custom_field) { FactoryGirl.create(:custom_field, :with_sub_custom_fields, company: company) }
    let(:custom_field_of_other_company) { FactoryGirl.create(:custom_field, :with_sub_custom_fields, company: other_company) }

    context 'User Without Logging In' do
      it 'should not be allowed to delete custom field' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :delete_sub_custom_fields, params: { id: custom_field.id }, format: :json
        expect(response).to have_http_status(401)
      end
    end

    context 'User after Logging in' do
      it 'should be able to delete sub custom fields of a custom field' do
        post :delete_sub_custom_fields, params: { id: custom_field.id }, format: :json
        expect(response).to have_http_status(204)
        custom_field.reload
        expect(custom_field.sub_custom_fields).to be_empty
      end

      it 'should not be able to delete sub custom fields of a custom field of another company' do
        post :delete_sub_custom_fields, params: { id: custom_field_of_other_company.id }, format: :json
        expect(response).to have_http_status(403)
      end
    end
  end

  context 'custom_groups_org_chart' do
    before do
      allow(controller).to receive(:current_user).and_return(admin_user)
    end
    it 'should be allowed to access custom groups org chart' do
      get :custom_groups_org_chart, params: { sub_tab: 'groups' }, format: :json
      expect(response).to have_http_status(200)
    end
  end

  context 'update_custom_group' do
    before do
      allow(controller).to receive(:current_user).and_return(admin_user)
    end
    let!(:custom_field) { FactoryGirl.create(:custom_field, :with_sub_custom_fields, company: company) }
    it 'should update custom group' do
      post :update_custom_group, params: { id: custom_field.id  }, format: :json
      expect(response.status).to eq(201)
    end
  end

  context 'get_adp_wfn_fields' do
    before do
      allow(controller).to receive(:current_user).and_return(admin_user)
    end
    let!(:custom_field) { FactoryGirl.create(:adp_rate_type_with_value, company: company) }
    it 'should return adp wfn fields' do
      get :get_adp_wfn_fields, params: { user_id: admin_user.id  }, format: :json
      expect(response.status).to eq(200)
    end
  end

  context 'duplicate' do
    before do
      allow(controller).to receive(:current_user).and_return(admin_user)
    end
    let!(:custom_field) { FactoryGirl.create(:adp_rate_type_with_value, company: company) }
    it 'should duplicate custom fields' do
      get :duplicate, params: { id: custom_field.id  }, format: :json
      expect(response.status).to eq(200)
    end
  end

  context 'update_user_custom_group' do
    before do
      allow(controller).to receive(:current_user).and_return(admin_user)
    end
    let!(:custom_field) { FactoryGirl.create(:adp_rate_type_with_value, company: company) }
    it 'should update user custom group' do
      get :update_user_custom_group, params: { id: custom_field.id, user_id: admin_user.id  }, format: :json
      expect(response.status).to eq(200)
    end
  end
end
