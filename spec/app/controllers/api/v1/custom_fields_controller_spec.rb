require 'rails_helper'
require "cancan/matchers"

RSpec.describe Api::V1::CustomFieldsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:tim) { create(:tim, state: :active, current_stage: :registered, company: company) }
  let(:gender) { create(:custom_field, name: 'Gender A', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:mobile_phone_number) { create(:custom_field, name: 'Mobile Phone Number', section: 'personal_info', field_type: 'simple_phone', company: company, skip_validations: true) }
  let(:ssn) { create(:custom_field, name: 'Social Security Number', section: 'private_info', field_type: 'social_security_number', company: company, skip_validations: true) }
  let(:dob) { create(:custom_field, name: 'Date of Birth', section: 'private_info', field_type: 'date', company: company, skip_validations: true) }
  let(:t_shirt) { create(:custom_field, name: 'T-Shirt Size', section: 'additional_fields', field_type: 'mcq', company: company, skip_validations: true) }
  let(:emergency_contact) { create(:custom_field, name: 'Emergency Contact Name', section: 'private_info', field_type: 'short_text', company: company, skip_validations: true) }
  let(:employment_status) { company.custom_fields.find_by(field_type: 13) }

  let(:home_address) { create(:custom_field, name: 'Home Address', section: 'private_info', field_type: 'address', company: company, skip_validations: true) }
  let(:line_one) { create(:sub_custom_field, custom_field_id: home_address.id, name: 'Line one', field_type: 'short_text') }
  let(:line_two) { create(:sub_custom_field, custom_field_id: home_address.id, name: 'Line two', field_type: 'short_text') }
  let(:city) { create(:sub_custom_field, custom_field_id: home_address.id, name: 'City', field_type: 'short_text') }
  let(:state) { create(:sub_custom_field, custom_field_id: home_address.id, name: 'State', field_type: 'short_text') }
  let(:country) { create(:sub_custom_field, custom_field_id: home_address.id, name: 'Country', field_type: 'short_text') }
  let(:zip) { create(:sub_custom_field, custom_field_id: home_address.id, name: 'Zip', field_type: 'short_text') }
  let(:admin_user) { create(:user, state: :active, current_stage: :registered, company: company, role: :admin) }
  let(:manager) { create(:nick, company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "PUT #update" do
    it "should update custom field of MCQ type by adding option" do
      post :update, params: { id: gender.id, custom_field_options: [{ option: 'Male' },
        { option: 'Female', position: 1 }, { option: 'Other', position: 2 }] }, format: :json
      gender.reload
      expect(gender.custom_field_options.count).to eq(3)
    end

    it "should update custom field of Mobile Phone Number by adding its value" do
      post :update, params: { id: mobile_phone_number.id, skip_validations: true, custom_field_value: { value_text: '1234567890', user_id: tim.id } }, format: :json
      mobile_phone_number.reload
      expect(mobile_phone_number.custom_field_values.first.value_text).to eq('1234567890')
    end

    it "should update custom field of Mobile Phone Number by adding its value" do
      post :update, params: { id: mobile_phone_number.id, skip_validations: true, custom_field_value: { value_text: '1234567890', user_id: tim.id } }, format: :json
      mobile_phone_number.reload
      expect(mobile_phone_number.custom_field_values.first.value_text).to eq('1234567890')
    end

    it "should update custom field of Social Security Number by adding its value" do
      post :update, params: { id: ssn.id, skip_validations: true, custom_field_value: { value_text: '0123456789', user_id: tim.id } }, format: :json
      ssn.reload
      expect(ssn.custom_field_values.first.value_text).to eq('0123456789')
    end

    it "should update custom field of Date of Birth by adding its value" do
      post :update, params: { id: dob.id, skip_validations: true, custom_field_value: { value_text: '1996-11-08', user_id: tim.id } }, format: :json
      dob.reload
      expect(dob.custom_field_values.first.value_text).to eq('1996-11-08')
    end

    it "should update custom field of Gender by adding its value" do
      post :update, params: { id: gender.id, custom_field_options: [{ option: 'Male' }] }, format: :json
      gender.reload
      expect(gender.custom_field_options.first.option).to eq('Male')
    end

    it "should update custom field of T Shirt by adding its value" do
      post :update, params: { id: t_shirt.id, skip_validations: true, custom_field_options: [{ option: 'X-Large' }] }, format: :json
      t_shirt.reload
      expect(t_shirt.custom_field_options.first.option).to eq('X-Large')
    end

    it "should update custom field of Emergency Contact Name by adding its value" do
      post :update, params: { id: emergency_contact.id, skip_validations: true, custom_field_value: { value_text: 'Dad' } }, format: :json
      emergency_contact.reload
      expect(emergency_contact.custom_field_values.first.value_text).to eq('Dad')
    end

    it "should update custom field of Employment Status by adding its value" do
      post :update, params: { id: employment_status.id, custom_field_options: [{ option: 'Full Time' }] }, format: :json
      employment_status.reload
      expect(employment_status.custom_field_options.first.option).to eq('Full Time')
    end

    it "should update custom field of Home Address Street 1 by adding its value" do
      post :update, params: { id: home_address.id, skip_validations: true, custom_field_value: { sub_custom_field_id: line_one.id, value_text: 'Street 1' } }, format: :json
      home_address.reload
      expect(home_address.custom_field_values.first.value_text).to eq('Street 1')
    end

    it "should update custom field of Home Address Street 2 by adding its value" do
      post :update, params: { id: home_address.id, skip_validations: true, custom_field_value: { sub_custom_field_id: line_two.id, value_text: 'Street 2' } }, format: :json
      home_address.reload
      expect(home_address.custom_field_values.first.value_text).to eq('Street 2')
    end

    it "should update custom field of Home Address City by adding its value" do
      post :update, params: { id: home_address.id, skip_validations: true, custom_field_value: { sub_custom_field_id: city.id, value_text: 'Santa Clara' } }, format: :json
      home_address.reload
      expect(home_address.custom_field_values.first.value_text).to eq('Santa Clara')
    end

    it "should update custom field of Home Address State by adding its value" do
      post :update, params: { id: home_address.id, skip_validations: true, custom_field_value: { sub_custom_field_id: state.id, value_text: 'California' } }, format: :json
      home_address.reload
      expect(home_address.custom_field_values.first.value_text).to eq('California')
    end

    it "should update custom field of Home Address Country by adding its value" do
      post :update, params: { id: home_address.id, skip_validations: true, custom_field_value: { sub_custom_field_id: country.id, value_text: 'Country' } }, format: :json
      home_address.reload
      expect(home_address.custom_field_values.first.value_text).to eq('Country')
    end

    it "should update custom field of Home Address Zip by adding its value" do
      post :update, params: { id: home_address.id, skip_validations: true, custom_field_value: { sub_custom_field_id: zip.id, value_text: '52025' } }, format: :json
      home_address.reload
      expect(home_address.custom_field_values.first.value_text).to eq('52025')
    end

    context 'updating custom_field with sub_custom_fields' do
      let(:nick){ create(:nick, company: company) }
      let!(:custom_field){ create(:address_with_multiple_sub_custom_fields, company: company) }
      before do
        first_sub_custom_field_id = custom_field.sub_custom_fields.order('id asc').first.id
        @params = {id: "#{custom_field.id}", section: "private_info", position: 3, name: "Home Address",
          help_text: nil, field_type: "address", required: true, required_existing: nil, collect_from: "new_hire",
          custom_table_id: nil, custom_table_property: nil, profile_setup: "profile_fields",
          display_location: nil, is_sensitive_field: false, custom_field_value: nil, custom_field_options: nil,
          locks: {all_locks: false}, integration_group: "no_integration", ats_mapping_key: nil, ats_mapping_section: nil,
          ats_mapping_field_type: nil, workday_mapping_key: nil, sub_custom_fields: [{id: "#{first_sub_custom_field_id}", name: "Line 1", field_type: "short_text",
          help_text: "Line 1", custom_field_value: {value_text: 'Line 1 address'}}, {id: "#{first_sub_custom_field_id + 1}", name: "Line 2", field_type: "short_text", help_text: "Line 2",
          custom_field_value: {value_text: 'Line 2 address'}}, {id: "#{first_sub_custom_field_id + 2}", name: "City", field_type: "short_text", help_text: "City",
          custom_field_value: nil}, {id: "#{first_sub_custom_field_id + 3}", name: "Country", field_type: "short_text", help_text: "Country",
          custom_field_value: {value_text: "United States"}}, {id: "#{first_sub_custom_field_id + 4}", name: "State", field_type: "short_text", help_text: "State",
          custom_field_value: nil}, {id: "#{first_sub_custom_field_id + 5}", name: "Zip", field_type: "short_text", help_text: "Zip/ Post Code",
          custom_field_value: nil}], visibility: true, user_id: "#{nick.id}", skip_validations: true}
      end
      context 'updating user_address (cfv with sub_custom_fields)' do
        before do
          put :update, params: @params, as: :json
        end
        it 'should update address line1 in cfv' do
          sub_custom_field = custom_field.sub_custom_fields.find_by_name('Line 1')
          expect(nick.reload.custom_field_values.find_by_sub_custom_field_id(sub_custom_field.id).value_text)
          .to eq('Line 1 address')
        end
        it 'should update address line2 in cfv' do
          sub_custom_field = custom_field.sub_custom_fields.find_by_name('Line 2')
          expect(nick.reload.custom_field_values.find_by_sub_custom_field_id(sub_custom_field.id).value_text)
          .to eq('Line 2 address')
        end
      end
    end
  end

  describe 'abilities' do
    subject(:ability) { Ability.new(user) }
    let(:user) { nil }
    let(:custom_field) { FactoryGirl.create(:custom_field, company: company) }
    let(:employee) { create(:user, role: :employee, company: company) }

    context 'when user is super admin' do
      let(:user) { FactoryGirl.create(:user, company: company) }
      it{ should be_able_to(:manage, custom_field) }
    end

    context 'when user is admin' do
      let(:user) { FactoryGirl.create(:taylor, company: company) }
      it{ should be_able_to(:manage, custom_field) }
    end

    context 'when user is manager' do
      let(:user) { FactoryGirl.create(:nick, company: company) }
      before do
        employee.update(manager_id: user.id)
        user.update(user_role_id: nil)
      end

      it{ should_not be_able_to(:manage, custom_field) }
    end

    context 'when user is employee' do
      let(:user) { employee }
      it{ should_not be_able_to(:manage, custom_field) }
    end
  end

  describe "GET #index" do

    it "should get the custom fields of other user's profile" do
      get :index, params: { section: 'private_info', user_id: user.id }, format: :json
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      json.each { |custom_field| expect(custom_field['section']).to eq('private_info') }
    end

    it "should get the custom fields of current user's profile" do
      get :index, params: { section: 'private_info' }, format: :json
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      json.each { |custom_field| expect(custom_field['section']).to eq('private_info') }
    end

    it "should not provide custom fields of a user without company" do
      user.company = nil
      get :index, params: { section: 'private_info', user_id: user.id }, format: :json
      expect(response).to have_http_status(403)
    end

    it "should not provide custom fields of a user without logging in" do
      allow(controller).to receive(:current_user).and_return(nil)
      get :index, params: { section: 'private_info', user_id: user.id }, format: :json
      expect(response).to have_http_status(401)
    end

    it "should not provide own custom fields of a user without logging in" do
      allow(controller).to receive(:current_user).and_return(nil)
      get :index, params: { section: 'private_info', user_id: user.id }, format: :json
      expect(response).to have_http_status(401)
    end

    it "should not provide custom fields of a user that belongs to a different company" do
      diff_company = create(:company)
      diff_user = create(:user, company: diff_company)
      get :index, params: { section: 'private_info', user_id: diff_user.id }, format: :json
      expect(response).to have_http_status(403)
    end

    it "should not provide custom fields of a deleted user" do
      user.destroy
      get :index, params: { section: 'private_info', user_id: user.id }, format: :json
      expect(response).to have_http_status(403)
    end

    describe 'Record Visibility Permissions' do
      let(:employee) { create(:user, role: :employee, company: company) }
      context 'Super Admin' do
        it "should be able to access own custom fields of all sections" do
          get :index, params: { section: 'private_info', user_id: user.id }, format: :json
          permissions = user.user_role.permissions['employee_record_visibility']
          expect(response).to have_http_status(200)
          json = JSON.parse(response.body)
          json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
        end
      end

      context 'Admin' do
        context 'with view and edit access' do
          before do
            admin_user.user_role.permissions['own_info_visibility']['private_info'] = 'view_and_edit'
            admin_user.user_role.permissions['employee_record_visibility']['private_info'] = 'view_and_edit'
            admin_user.user_role.save
            allow(controller).to receive(:current_user).and_return(admin_user)
          end
          it "should be able to access own custom fields" do
            get :index, params: { section: 'private_info', user_id: admin_user.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end

          it "should be able to access other user custom fields" do
            get :index, params: { section: 'private_info', user_id: employee.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end
        end

        context 'with view access' do
          before do
            admin_user.user_role.permissions['own_info_visibility']['private_info'] = 'view'
            admin_user.user_role.permissions['employee_record_visibility']['private_info'] = 'view'
            admin_user.user_role.save
            allow(controller).to receive(:current_user).and_return(admin_user)
          end
          it "should be able to access own custom fields" do
            get :index, params: { section: 'private_info', user_id: admin_user.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end

          it "should be able to access other user custom fields" do
            get :index, params: { section: 'private_info', user_id: employee.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end
        end

        context 'with no access' do
          before do
            admin_user.user_role.permissions['employee_record_visibility']['private_info'] = 'no_access'
            admin_user.user_role.permissions['own_info_visibility']['private_info'] = 'no_access'
            admin_user.user_role.save
            allow(controller).to receive(:current_user).and_return(admin_user)
          end
          it "should not be able to access own custom fields" do
            get :index, params: { section: 'private_info', user_id: admin_user.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq('personal_info').or eq('additional_info') }
          end

          it "should not be able to access other user custom fields" do
            get :index, params: { section: 'private_info', user_id: employee.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq('personal_info').or eq('additional_info') }
          end
        end
      end

      context 'Manager' do
        before do
          employee.update(manager_id: manager.id)
          manager.update(user_role_id: nil)
        end
        context 'with view and edit access' do
          before do
            manager.user_role.permissions['own_info_visibility']['private_info'] = 'view_and_edit'
            manager.user_role.permissions['employee_record_visibility']['private_info'] = 'view_and_edit'
            manager.user_role.save
            allow(controller).to receive(:current_user).and_return(manager)
          end
          it "should be able to access own custom fields" do
            get :index, params: { section: 'private_info', user_id: manager.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end

          it "should be able to access other user custom fields" do
            get :index, params: { section: 'private_info', user_id: employee.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end
        end

        context 'with view access' do
          before do
            manager.user_role.permissions['own_info_visibility']['private_info'] = 'view'
            manager.user_role.permissions['employee_record_visibility']['private_info'] = 'view'
            manager.user_role.save
            allow(controller).to receive(:current_user).and_return(manager)
          end
          it "should be able to access own custom fields" do
            get :index, params: { section: 'private_info', user_id: manager.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end

          it "should be able to access other user custom fields" do
            get :index, params: { section: 'private_info', user_id: employee.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end
        end

        context 'with no access' do
          before do
            manager.user_role.permissions['employee_record_visibility']['private_info'] = 'no_access'
            manager.user_role.permissions['own_info_visibility']['private_info'] = 'no_access'
            manager.user_role.save
            allow(controller).to receive(:current_user).and_return(manager)
          end
          it "should not be able to access own custom fields" do
            get :index, params: { section: 'private_info', user_id: manager.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq('personal_info').or eq('additional_info') }
          end

          it "should not be able to access other user custom fields" do
            get :index, params: { section: 'private_info', user_id: employee.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq('personal_info').or eq('additional_info') }
          end
        end
      end

      context 'Employee' do
        context 'with view and edit access' do
          before do
            employee.user_role.permissions['employee_record_visibility']['private_info'] = 'view_and_edit'
            employee.user_role.save
            allow(controller).to receive(:current_user).and_return(employee)
          end
          it "should be able to access own custom fields" do
            get :index, params: { section: 'private_info', user_id: employee.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end

          it "should be able to access other user custom fields" do
            get :index, params: { section: 'private_info', user_id: admin_user.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end
        end

        context 'with view access' do
          before do
            employee.user_role.permissions['employee_record_visibility']['private_info'] = 'view'
            employee.user_role.save
            allow(controller).to receive(:current_user).and_return(employee)
          end
          it "should be able to access own custom fields" do
            get :index, params: { section: 'private_info', user_id: employee.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end

          it "should be able to access other user custom fields" do
            get :index, params: { section: 'private_info', user_id: admin_user.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq("private_info").or eq('personal_info').or eq('additional_info') }
          end
        end

        context 'with no access' do
          before do
            employee.user_role.permissions['employee_record_visibility']['private_info'] = 'no_access'
            employee.user_role.save
            allow(controller).to receive(:current_user).and_return(employee)
          end
          it "should not be able to access own custom fields" do
            get :index, params: { section: 'private_info', user_id: employee.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq('personal_info').or eq('additional_info') }
          end

          it "should not be able to access other user custom fields" do
            get :index, params: { section: 'private_info', user_id: admin_user.id }, format: :json
            expect(response).to have_http_status(200)
            json = JSON.parse(response.body)
            json.each { |custom_field| expect(custom_field['section']).to eq('personal_info').or eq('additional_info') }
          end
        end
      end
    end
  end

  describe "#preboarding_visible_field_index" do
    it "should return other user's preboarding visible fields" do
      CustomField.update_all(collect_from: 0)
      custom_field = create(:custom_field, company: company, collect_from: 0)
      other_user = create(:user , company: company)
      allow(controller).to receive(:current_user).and_return(user)
      get :preboarding_visible_field_index, params: { user_id: other_user.id, collect_from: 'new_hire' }, format: :json
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      json.each { |custom_field| expect(custom_field['collect_from']).to eq('new_hire') }
    end

    it "should return current user's preboarding visible fields" do
      CustomField.update_all(collect_from: 0)
      custom_field = create(:custom_field, company: company, collect_from: 0)
      get :preboarding_visible_field_index, format: :json, params: { collect_from: 'new_hire' }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      json.each { |custom_field| expect(custom_field['collect_from']).to eq('new_hire') }
    end

    it "should not return preboarding visible fields of a deleted user" do
      user.destroy
      get :preboarding_visible_field_index, params: { user_id: user.id, collect_from: 2 }, format: :json
      expect(response).to have_http_status(403)
    end

    it "should not return preboarding visible fields of a user without logging in" do
      allow(controller).to receive(:current_user).and_return(nil)
      get :preboarding_visible_field_index, params: { user_id: user.id, collect_from: 2 }, format: :json
      expect(response).to have_http_status(401)
    end

    it "should not return user's own preboarding visible fields without logging in" do
      allow(controller).to receive(:current_user).and_return(nil)
      get :preboarding_visible_field_index, format: :json, params: { collect_from: 2 }
      expect(response).to have_http_status(401)
    end

    it "should not return preboarding visible fields of a user from a different company" do
      diff_company = create(:company)
      diff_user = create(:user, company: diff_company)
      get :preboarding_visible_field_index, params: { user_id: diff_user.id, collect_from: 2 }, format: :json
      expect(response).to have_http_status(403)
    end
  end

  describe "#home_info_page_index" do
    let(:other_user) { create(:user , company: company) }
    before do
      allow(controller).to receive(:current_user).and_return(user)
    end

    it "should return other user's profile page custom fields" do
      get :home_info_page_index, params: { user_id: other_user.id }, format: :json
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      json.each { |custom_field| expect(custom_field['section']).to eq('personal_info').or  eq('profile').or eq('additional_fields').or eq('paperwork').or eq('private_info') }
    end

    it "should return current user's profile page custom fields" do
      get :home_info_page_index, params: { user_id: user.id }, format: :json
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      json.each { |custom_field| expect(custom_field['section']).to eq('personal_info').or  eq('profile').or eq('additional_fields').or eq('paperwork').or eq('private_info') }
    end

    it "should not return profile page custom fields of a user without logging in" do
      allow(controller).to receive(:current_user).and_return(nil)
      get :home_info_page_index, params: { user_id: other_user.id }, format: :json
      expect(response).to have_http_status(401)
    end

    it "should not return user's own profile page custom fields without logging in" do
      allow(controller).to receive(:current_user).and_return(nil)
      get :home_info_page_index, params: { user_id: user.id }, format: :json
      expect(response).to have_http_status(401)
    end

    it "should not return profile page custom fields of a user from a different company" do
      diff_company = create(:company)
      diff_user = create(:user, company: diff_company)
      get :home_info_page_index, params: { user_id: diff_user.id }, format: :json
      expect(response).to have_http_status(403)
    end
  end

  describe "#custom_groups" do
    it "should return company custom group" do
      custom_field = create(:custom_field, company: company, field_type: CustomField.field_types[:mcq], integration_group: CustomField.integration_groups[:namely])
      get :custom_groups, format: :json
      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      custom_field_received = json.first
      expect(custom_field_received['id']).to eq(custom_field.id)
      expect(custom_field_received['name']).to eq(custom_field.name)
    end

    it "should not return company custom group if user is not logged in" do
      allow(controller).to receive(:current_user).and_return(nil)
      get :custom_groups, format: :json
      expect(response).to have_http_status(401)
    end
  end

  describe "#home_group_field" do
    it "should return home group custom fields" do
      company.group_for_home = 'Test_Group'
      company.save
      custom_field = FactoryGirl.create(:custom_field, name: "Test_Group", company: company, field_type: CustomField.field_types[:mcq])
      get :home_group_field, params: { user_id: user.id }, format: :json
      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json['id']).to eq(custom_field.id)
      expect(json['name']).to eq(custom_field.name)
    end

    it "should not return home group custom fields without logging in" do
      allow(controller).to receive(:current_user).and_return(nil)
      get :home_group_field, format: :json
      expect(response).to have_http_status(401)
    end
  end

  describe "#mcq_custom_fields" do
    it "should return MCQ type custom fields" do
      custom_field = create(:custom_field, field_type: 4, company: user.company)
      get :mcq_custom_fields, format: :json
      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      json.each { |custom_field| expect(custom_field['field_type']).to eq('mcq').or eq('employment_status') }
    end

    it "should not return MCQ type custom fields if user is not logged in" do
      create(:custom_field, field_type: 4, company: user.company)
      allow(controller).to receive(:current_user).and_return(nil)
      get :mcq_custom_fields, format: :json
      expect(response).to have_http_status(401)
    end
  end

  describe "#preboarding_page_index" do
    it "should return preboarding page index" do
      allow(controller).to receive(:current_user).and_return(user)
      get :preboarding_page_index, format: :json
      expect(response).to have_http_status(200)
    end
  end

  describe "#people_page_custom_groups" do
    it "should return people page custom group" do
      custom_field = create(:custom_field, company: company, integration_group: CustomField.integration_groups[:namely])
      get :people_page_custom_groups, format: :json
      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
    end
  end
end