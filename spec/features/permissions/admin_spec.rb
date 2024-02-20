require 'feature_helper'

feature 'Permissions Test Cases', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo', enabled_calendar: true, enabled_time_off: true) }
  given!(:location) { create(:location, company: company) }
  given!(:team) { create(:team, company: company) }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:peter) { create(:peter, company: company, preferred_name: "") }
  given!(:tim) { create(:tim, company: company, preferred_name: "", team_id:team.id) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Admin Permission' do
    background{
      wait_all_requests
      navigate_to '/#/admin/settings/roles'
    }

    scenario 'Modify the admin permission to no_access and verify it' do
      open_admin_permission_role
      admin_permission_level('no_access')
      open_user_profile
      validate_admin_permissions_from_user('no_access')
      validate_platform_permissions_from_user('no_access')
    end

    scenario 'Modify the admin permission to view_only and verify it' do
      open_admin_permission_role
      admin_permission_level('view_only')
      open_user_profile
      validate_admin_permissions_from_user('view_only')
      wait 4
      validate_platform_permissions_from_user('view_only')
    end

    scenario 'Modify the admin permission to view_edit and verify it' do
      open_admin_permission_role
      admin_permission_level('view_edit')
      open_user_profile
      validate_admin_permissions_from_user('view_edit')
      validate_platform_permissions_from_user('view_edit')
    end

    scenario 'Add new admin permission and verify it' do
      create_new_admin_permission
      admin_permission_level('no_access')
      verify_new_create_permission
      add_admin_members_new_permission
      open_user_profile
      validate_admin_permissions_from_user('no_access')
      validate_platform_permissions_from_user('no_access')
      delete_users_from_permission
    end

    scenario 'Update Permission and verify it' do
      update_admin_permission_role
      admin_permission_level('no_access')
      verify_admin_permission_role
    end
  end
end
