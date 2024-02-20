def open_employee_permission
    navigate_to '/#/admin/settings/roles'
    wait_all_requests
    find("#permission_levels li", :text => I18n.t('admin.settings.roles.employees')).click
    wait_all_requests
    page.find('#users_permission_role .role-name-column').click
    wait_all_requests
    expect(page).to have_content I18n.t('admin.settings.roles.role_information')
    click_link_or_button ('Next')
    wait_all_requests
end

def employee_permission_level(selector)
    expect(page).to have_content I18n.t('admin.settings.roles.employee_platform_visibility')
    if selector == 'no_access'
        find("#profile_info_view_only").click
    else
        find("#profile_info_view_edit").click
    end

    find("#tasks_#{selector}").click
    find("#documents_#{selector}").click
    if selector != 'view_edit'
        find("#people_#{selector}").click
    else
        find("#people_view_only").click
    end
    click_button('Next')
    wait_all_requests
    expect(page).to have_content I18n.t('admin.settings.roles.employee_record_visibility')
    find("#personal_info_#{selector}").click
    find("#additional_info_#{selector}").click
    find("#private_info_#{selector}").click
end

def employee_custom_tables_permission(selector)
    page.execute_script("$('#employee_permission #custom_table_permissions ##{selector}_permission:eq(0)').click()")
    page.execute_script("$('#employee_permission #custom_table_permissions ##{selector}_permission:eq(1)').click()")
    page.execute_script("$('#employee_permission #custom_table_permissions ##{selector}_permission:eq(2)').click()")
    click_button('Next')
    page.execute_script("$('#employee_permission #custom_table_permissions ##{selector}_permission:eq(0)').click()")
    page.execute_script("$('#employee_permission #custom_table_permissions ##{selector}_permission:eq(1)').click()")
    page.execute_script("$('#employee_permission #custom_table_permissions ##{selector}_permission:eq(2)').click()")
    click_button('Submit')
end

def login_with_agatha
	wait_all_requests
    find('#user-menu .icon-chevron-down').click
    wait_all_requests
    click_button(I18n.t('admin.header.menu.sign_out'))
    wait_all_requests
    wait(1)
    fill_in :email , with: 'agatha.company@test.com'
    fill_in :password , with: ENV['USER_PASSWORD']
    click_button('Sign In')
    wait_all_requests
    wait(8)
end

def verify_employee_permissions(selector)
	wait_all_requests

    expect(page).to have_selector('[id="updates_container"]')

    plateform_menu_items = Array.new
    tab_headings = page.all('md-tab-item')
    tab_headings.each do |raw|
        plateform_menu_items.push(raw.text)
    end

    if selector == 'no_access'
        expect(plateform_menu_items).not_to include('Tasks', 'Documents')
        page.find('md-tab-item', :text => I18n.t('onboard.home.toolbar.profile')).click
        wait_all_requests
        wait(1)
        expect(page).to  have_no_content("Personal Information")
        expect(page).to  have_no_content("Private Information")
        expect(page).to  have_no_content("Additional Information")

    elsif selector == 'view_only'
        verify_view_only_plateform_permission(plateform_menu_items)

    elsif selector == 'view_edit'
       verify_view_edit_plateform_permission(plateform_menu_items)

    end

end

def verify_view_only_plateform_permission(plateform_menu_items)
    expect(plateform_menu_items).to include('Tasks', 'Documents')
    page.find('md-tab-item', :text => "Tasks").click
    wait_all_requests
    wait(1)
    expect(page).to have_selector('.md-active', :text => 'Tasks')
    expect(page).to have_no_content I18n.t('admin.onboard.workstream.assign_heading')
    page.find('md-tab-item', :text => "Documents").click
    wait_all_requests
    wait(1)
    expect(page).to have_selector('.md-active', :text => 'Documents')
    expect(page).to have_no_content I18n.t('admin.documents.paperwork.add_document')
    page.find('md-tab-item', :text => I18n.t('onboard.home.toolbar.profile')).click
    wait_all_requests
    wait(1)
    expect(page).to have_no_selector('[name="edit_personal_info"]')
    expect(page).to have_no_selector('[name="edit_additional_info"]')
    expect(page).to have_no_selector('[name="edit_private_info"]')
end

def verify_view_edit_plateform_permission(plateform_menu_items)
    expect(plateform_menu_items).to include('Tasks', 'Documents')
    page.find('md-tab-item', :text => "Tasks").click
    wait_all_requests
    wait(1)
    wait_all_requests
    expect(page).to have_content('ASSIGN WORKFLOW')
    expect(page).to have_selector('.md-active', :text => 'Tasks')
    page.find('md-tab-item', :text => "Documents").click
    wait_all_requests
    wait(1)
    wait_all_requests
    expect(page).to have_content('Assign')
    expect(page).to have_selector('.md-active', :text => 'Documents')
    page.find('md-tab-item', :text => I18n.t('onboard.home.toolbar.profile')).click
    wait_all_requests
    wait(1)
    wait_all_requests
    page.all('.section-right-approval-icons .icon-pencil').each do |el|
      el.trigger('click')
    end
    expect(page).to have_selector('[name="edit_personal_info"]')
    expect(page).to have_selector('[name="edit_additional_info"]')
    expect(page).to have_selector('[name="edit_private_info"]')
end

def create_new_employee_permission
    navigate_to '/#/admin/settings/roles'
    find("#permission_levels li", :text => I18n.t('admin.settings.roles.employees')).click
    wait_all_requests
    click_button I18n.t('admin.settings.roles.add_new_role')
    wait_all_requests
    page.find('#role_name').set('Test Permission')
    click_button('Next')
end

def verify_new_employee_create_permission
    expect(page).to have_selector('#users_permission_role')
    permission_name = page.find('#users_permission_role li:nth-child(2) .role-name-column').text
    expect(permission_name).to eq('Test Permission')
end

def add_members_new_permission
    page.find('#users_permission_role li:nth-child(2) .roles_edit_members').trigger('click')
    choose_item_from_autocomplete('add_members', "#{agatha.first_name} #{agatha.last_name}")
    page.find('.md-toolbar-tools .md-icon-button .icon-close').trigger('click')
    wait_all_requests
    total_members = page.find('#users_permission_role li:nth-child(2) .user_count').text
    expect(total_members).to eq('1')
end

def open_test_permission
    navigate_to '/#/admin/settings/roles'
    find("#permission_levels li", :text => I18n.t('admin.settings.roles.employees')).trigger('click')
    wait_all_requests
    page.find('#users_permission_role li:nth-child(2)').trigger('click')
    wait_all_requests
    click_button('Next')
end
