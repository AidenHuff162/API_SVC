require 'feature_helper'

feature 'Permissions Test Cases', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo', is_using_custom_table: true) }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:tim) { create(:tim, company: company, preferred_name: "") }
  given!(:nick) { create(:nick, company: company, preferred_name: "", manager: tim) }
  given!(:location) { create(:location, company: company) }
  given!(:nick) { create(:nick, company: company, preferred_name: "", manager_id: tim.id) }

  given!(:manager) { create(:user, company: company, preferred_name: "") }
  given!(:buddy) { create(:user, company: company, preferred_name: "") }
  given!(:team) { create(:team, company: company) }

  given(:user_attributes) { attributes_for(:user) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Verify Super Admin Permissions' do
    scenario 'Modify the admin permission to no_access and verify it' do
      # assign_manager_to_user
      open_manager_permission
      manager_permission_level('no_access')
      manager_custom_tables_permission('no_access')
      login_with_tim
      verify_manager_own_permissions('no_access')
      # verify_manager_team_permissions('no_access')
      login_with_sarah
      open_manager_permission
      manager_permission_level('view_only')
      manager_custom_tables_permission('view_only')
      login_with_tim
      verify_manager_own_permissions('view_only')
      verify_manager_team_permissions('view_only')
      login_with_sarah
      open_manager_permission
      manager_permission_level('view_edit')
      manager_custom_tables_permission('view_edit')
      login_with_tim
      verify_manager_own_permissions('view_edit')
      verify_manager_team_permissions('view_edit')
    end
  end
end
