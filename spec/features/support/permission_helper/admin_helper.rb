def open_admin_permission_role
  find('#permission_levels li:nth-child(3)', :text => I18n.t('admin.settings.roles.admins')).click
  find('#users_permission_role .role-name-column').click
  wait_all_requests
  expect(page).to have_content I18n.t('admin.settings.roles.role_information')
  fill_in "description_role", with: sarah.first_name
  setting_permission_level
  page.find('[ng-click="MsStepper.gotoNextStep()"]').trigger('click')
  page.find('[ng-click="MsStepper.gotoNextStep()"]').trigger('click')
end

def setting_permission_level
  choose_item_from_multi_select_dropdown('departments_permission_level', team.id)
  choose_item_from_multi_select_dropdown('locations_permission_level', location.id)
end

def admin_permission_level(selector)
  expect(page).to have_content I18n.t('admin.settings.roles.admin_platform_visibility')
  if selector == 'no_access'
    find("#profile_info_view_only").trigger('click')
  else
    find("#profile_info_#{selector}").trigger('click')
  end
  find("#tasks_#{selector}").trigger('click')
  find("#documents_#{selector}").trigger('click')
  find("#people_#{selector}").trigger('click')
  page.find('[ng-click="MsStepper.gotoNextStep()"]').trigger('click')
  wait_all_requests
  expect(page).to have_content I18n.t('admin.settings.roles.employee_record_visibility')
  find("#personal_info_#{selector}").trigger('click')
  find("#additional_info_#{selector}").trigger('click')
  find("#private_info_#{selector}").trigger('click')
  page.execute_script("$('#manager_permissions md-divider:nth-child(3) ##{selector}_permission').click()")
  page.execute_script("$('#manager_permissions md-divider:nth-child(4) ##{selector}_permission').click()")
  page.execute_script("$('#manager_permissions md-divider:nth-child(5) ##{selector}_permission').click()")
  page.find('[ng-click="MsStepper.gotoNextStep()"]').trigger('click')
  wait_all_requests
  expect(page).to have_content I18n.t('admin.settings.roles.admin_record_visibility')
  find("#personal_info_#{selector}").trigger('click')
  find("#additional_info_#{selector}").trigger('click')
  find("#private_info_#{selector}").trigger('click')
  page.execute_script("$('#employee_permission md-divider:nth-child(3) ##{selector}_permission').click()")
  page.execute_script("$('#employee_permission md-divider:nth-child(4) ##{selector}_permission').click()")
  page.execute_script("$('#employee_permission md-divider:nth-child(5) ##{selector}_permission').click()")
  page.find('[ng-click="MsStepper.gotoNextStep()"]').trigger('click')
  wait_all_requests
  expect(page).to have_content I18n.t('admin.settings.roles.admin_section_visibility')
  if selector != 'view_only'
    find("#dashboard_#{selector}").trigger('click')
    find("#reports_#{selector}").trigger('click')
    find("#tasks_#{selector}").trigger('click')
    find("#documents_#{selector}").trigger('click')
    find("#emails_#{selector}").trigger('click')
    find("#records_#{selector}").trigger('click')
    find("#permission_#{selector}").trigger('click')
    find("#company_#{selector}").trigger('click')
    find("#groups_#{selector}").trigger('click')
    find("#integrations_#{selector}").trigger('click')
  end
  page.find('[ng-click="MsStepper.resetForm()"]').trigger('click')
  wait_all_requests
  expect(page).to have_content I18n.t('admin.settings.roles.title_hint')
end

def open_user_profile
  find('#user-menu button').trigger('click')
  wait_all_requests
  click_button(I18n.t('admin.header.menu.sign_out'))
  Auth.sign_in_user peter, peter.password
  wait_all_requests
  navigate_to("/#/profile/#{tim.id}")
end

def validate_admin_permissions_from_user(selector)
  wait(2)
  if selector == 'view_edit'
    page.find(:css,'.md-locked-open').hover
    wait_all_requests
    page.find('#ms-navigation-fold-expander').trigger('click')
    admin_sidebar = Array.new()
    admin = page.all('#sidenav-title')
    admin.each do |raw|
        admin_sidebar.push(raw.text)
    end
    expect(admin_sidebar).to include('Dashboard', 'Reports', 'Workflows', 'Documents', 'Profile Setup', 'Permissions', 'Platform', 'Groups', 'Integrations')
    expect(admin_sidebar.count).to eq(10)
  end
end

def validate_platform_permissions_from_user(selector)
  wait_all_requests
  if selector == 'view_edit'
    page.all('.section-right-approval-icons .icon-pencil')[0].trigger('click')
    expect(page).to have_selector('[name="edit_profile_info"]')
  else
    expect(page).to have_no_selector('[name="edit_profile_info"]')
  end
  plateform_menu_items = Array.new
  tab_headings = page.all('md-tab-item')
  tab_headings.each do |raw|
    plateform_menu_items.push(raw.text)
  end
  
  if selector == 'no_access'
    expect(plateform_menu_items).not_to include('Tasks', 'Documents', 'Job Details')
    page.find('md-tab-item', :text => I18n.t('onboard.home.toolbar.profile')).click
    wait_all_requests
    wait(1)
    expect(page).to have_no_selector('[name="edit_personal_info"]')
    expect(page).to have_no_selector('[name="edit_additional_info"]')
    expect(page).to have_no_selector('[name="edit_private_info"]')
  elsif selector == 'view_only'
    validate_view_only_plateform_permission(plateform_menu_items)
  elsif selector == 'view_edit'
    validate_view_edit_plateform_permission(plateform_menu_items)
  end
end

def validate_view_only_plateform_permission(plateform_menu_items)
  expect(plateform_menu_items).to include('Tasks', 'Documents', 'Job Details')
  page.find('md-tab-item', :text => "Tasks").trigger('click')
  wait(2)
  expect(page).to have_selector('.md-active', :text => 'Tasks')
  expect(page).to have_no_content I18n.t('admin.onboard.workstream.assign_heading')
  page.find('md-tab-item', :text => "Documents").trigger('click')
  wait(2)
  expect(page).to have_selector('.md-active', :text => 'Documents')
  expect(page).to have_no_content I18n.t('admin.documents.paperwork.add_document')
  page.find('md-tab-item', :text => "Job Details").trigger('click')
  wait(2)
  expect(page).to have_selector('.md-active', :text => 'Job Details')
  expect(page).to have_no_selector('.update_custom_table')
  page.find('md-tab-item', :text => "Profile").trigger('click')
  wait(2)
  expect(page).to have_selector('.md-active', :text => I18n.t('onboard.home.toolbar.profile'))
  expect(page).to have_no_selector('[name="edit_personal_info"]')
  expect(page).to have_no_selector('[name="edit_additional_info"]')
  expect(page).to have_no_selector('[name="edit_private_info"]')
end

def validate_view_edit_plateform_permission(plateform_menu_items)
  expect(plateform_menu_items).to include('Tasks', 'Documents')
  page.find('md-tab-item', :text => "Tasks").trigger('click')
  wait(2)
  expect(page).to have_selector('.md-active', :text => 'Tasks')
  expect(page).to have_selector('#add_workflow_button', :text => I18n.t('admin.onboard.assign_activities.workstream.assign_heading').upcase)
  page.find('md-tab-item', :text => "Documents").trigger('click')
  wait(2)
  expect(page).to have_selector('.md-active', :text => 'Documents')
  expect(page).to have_content I18n.t('admin.documents.paperwork.add_document')
  page.find('md-tab-item', :text => "Job Details").trigger('click')
  wait(2)
  expect(page).to have_selector('.md-active', :text => 'Job Details')
  expect(page).to have_selector('#update_custom_table')
  page.find('md-tab-item', :text => "Profile").trigger('click')
  wait(2)
  expect(page).to have_selector('.md-active', :text => I18n.t('onboard.home.toolbar.profile'))
  page.all('.section-right-approval-icons .icon-pencil').each do |el|
    el.trigger('click')
  end
  expect(page).to have_selector('[name="edit_personal_info"]')
  expect(page).to have_selector('[name="edit_additional_info"]')
  expect(page).to have_selector('[name="edit_private_info"]')
end

def create_new_admin_permission
  find("#permission_levels li:nth-child(3)", :text => I18n.t('admin.settings.roles.admins')).click
  wait_all_requests
  click_button I18n.t('admin.settings.roles.add_new_role')
  wait_all_requests
  page.find('#role_name').set('Test Permission')
  click_button('Next')
  click_button('Next')
end

def verify_new_create_permission
  find("#permission_levels li:nth-child(3)", :text => I18n.t('admin.settings.roles.admins')).click
  expect(page).to have_selector('#users_permission_role')
  permission_name = page.find('#users_permission_role li:nth-child(2) .role-name-column').text
  expect(permission_name).to eq('Test Permission')
end

def add_admin_members_new_permission
    page.find('#users_permission_role li:nth-child(2) .roles_edit_members').trigger('click')
    wait_all_requests
    choose_item_from_autocomplete('add_members', "#{peter.first_name} #{peter.last_name}")
    wait_all_requests
    page.find('.md-toolbar-tools .md-icon-button .icon-close').trigger('click')
    wait_all_requests
    total_members = page.find('#users_permission_role li:nth-child(2) .user_count').text
    expect(total_members).to eq('1')
end

def open_admin_new_permission
  navigate_to '/#/admin/settings/roles'
  find("#permission_levels li", :text => I18n.t('admin.settings.roles.admins')).trigger('click')
  wait_all_requests
  page.find('#users_permission_role li:nth-child(2)').trigger('click')
  wait_all_requests
  click_button('Next')
end

def delete_users_from_permission
  find('#user-menu button').trigger('click')
  wait_all_requests
  click_button(I18n.t('admin.header.menu.sign_out'))
  Auth.sign_in_user sarah, sarah.password
  navigate_to '/#/admin/settings/roles'
  find('#permission_levels li:nth-child(3)', :text => I18n.t('admin.settings.roles.admins')).click
  wait_all_requests
  page.find('#users_permission_role li:nth-child(2) .roles_edit_members').trigger('click')
  page.find('.action .icon-delete').trigger('click')
end

def update_admin_permission_role
  find('#permission_levels li:nth-child(3)', :text => I18n.t('admin.settings.roles.admins')).click
  find('#users_permission_role .role-name-column').click
  wait_all_requests
  expect(page).to have_content I18n.t('admin.settings.roles.role_information')
  fill_in "role_name", with: "Admin Permissions"
  fill_in "description_role", with: "Admin Permissions For Users"
  click_button('Next')
  click_button('Next')
end

def verify_admin_permission_role
  find('#permission_levels li:nth-child(3)', :text => I18n.t('admin.settings.roles.admins')).click
  find('#users_permission_role .role-name-column').click
  wait_all_requests
  expect(page).to have_content I18n.t('admin.settings.roles.role_information')
  role_name = page.find('#role_name').value
  expect(role_name).to eq('Admin Permissions')
  role_desc = page.find('#description_role').value
  expect(role_desc).to eq('Admin Permissions For Users')
end
