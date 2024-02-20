require 'feature_helper'

feature 'Permissions Test Cases', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:agatha) { create(:agatha, company: company, preferred_name: "") }
  given!(:location) { create(:location, company: company) }

  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Verify Super Admin Permissions' do
    background{
      wait_all_requests
    }
    scenario 'Modify the Employee Permissions and verify it' do
      open_employee_permission
      employee_permission_level('no_access')
      employee_custom_tables_permission('no_access')
      login_with_agatha
      verify_employee_permissions('no_access')
      login_with_sarah
      open_employee_permission
      employee_permission_level('view_only')
      employee_custom_tables_permission('view_only')
      login_with_agatha
      verify_employee_permissions('view_only')
      login_with_sarah
      open_employee_permission
      employee_permission_level('view_edit')
      employee_custom_tables_permission('view_edit')
      login_with_agatha
      verify_employee_permissions('view_edit')
    end
    scenario 'Create New Employee Permissions and verify it' do
      create_new_employee_permission
      employee_permission_level('no_access')
      employee_custom_tables_permission('no_access')
      verify_new_employee_create_permission
      add_members_new_permission
      login_with_agatha
      verify_employee_permissions('no_access')
      login_with_sarah
      open_test_permission
      employee_permission_level('view_only')
      employee_custom_tables_permission('view_only')
      login_with_agatha
      verify_employee_permissions('view_only')
      login_with_sarah
      open_test_permission
      employee_permission_level('view_edit')
      employee_custom_tables_permission('view_edit')
      login_with_agatha
      verify_employee_permissions('view_edit')
    end
  end
end
