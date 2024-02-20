def assign_manager_to_user
    navigate_to "/#/role/#{nick.id}"
    wait_all_requests
    # page.find('md-tab-item', :text => ('Job Details')).click
    # wait_all_requests
    page.find('.information-block:nth-child(1) #update_custom_table').click
    wait_all_requests
    effective_date = (Date.today - 1).strftime("%m/%d/%Y")
    page.execute_script("$('.md-datepicker-input').val('#{effective_date}').trigger('input')")
    wait_all_requests
    choose_item_from_autocomplete("manager","#{tim.first_name} #{tim.last_name}")
    click_link_or_button ('Submit')
    page.find('md-tab-item', :text => ('Profile')).click
    wait_all_requests
end

def open_manager_permission
    wait_all_requests
    wait(5)
    navigate_to '/#/admin/settings/roles'
    wait_all_requests
    wait(5)
    find("#permission_levels li", :text => I18n.t('admin.settings.roles.managers')).click
    wait_all_requests
    page.find('#users_permission_role .role-name-column').click
    wait_all_requests
    expect(page).to have_content I18n.t('admin.settings.roles.role_information')
    click_link_or_button ('Next')
    wait_all_requests
end

def manager_permission_level(selector)
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
    expect(page).to have_content I18n.t('admin.settings.roles.manager_platform_visibility')
    if selector == 'no_access'
        find("#profile_info_view_only").click
    else
        find("#profile_info_view_edit").click
    end

    find("#tasks_#{selector}").click
    find("#documents_#{selector}").click
    click_button('Next')
    wait_all_requests
    expect(page).to have_content I18n.t('admin.settings.roles.manager_employee_record_visibility')
    find("#personal_info_#{selector}").click
    find("#additional_info_#{selector}").click
    find("#private_info_#{selector}").click
    click_button('Next')
    expect(page).to have_content I18n.t('admin.settings.roles.manager_record_visibility')
    find("#personal_info_#{selector}").click
    find("#additional_info_#{selector}").click
    find("#private_info_#{selector}").click
end

def manager_custom_tables_permission(selector)
    page.execute_script("$('#manager_permissions #table_info_permissions ##{selector}_permission:eq(0)').click()")
    page.execute_script("$('#manager_permissions #table_info_permissions ##{selector}_permission:eq(1)').click()")
    page.execute_script("$('#manager_permissions #table_info_permissions ##{selector}_permission:eq(2)').click()")
    click_button('Submit')
end

def login_with_tim
    wait_all_requests
    find('#user-menu .icon-chevron-down').click
    wait_all_requests
    click_button(I18n.t('admin.header.menu.sign_out'))
    wait_all_requests
    wait(1)
    fill_in :email , with: 'tim@test.com'
    fill_in :password , with: ENV['USER_PASSWORD']
    click_button('Sign In')
    wait_all_requests
end

def verify_manager_own_permissions(selector)
    page.find('md-tab-item', :text => "Profile").click
    if selector == 'no_access'
        expect(page).to have_no_selector('[name="edit_profile_info"]')
    else 
      expect(page).to have_no_selector('[name="edit_profile_info"]')
    end

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
        expect(page).to have_selector('.md-active', :text => I18n.t('onboard.home.toolbar.profile'))
        expect(page).to have_no_selector('[name="edit_personal_info"]')
        expect(page).to have_no_selector('[name="edit_additional_info"]')
        expect(page).to have_no_selector('[name="edit_private_info"]')

    elsif selector == 'view_edit'
        expect(plateform_menu_items).to include('Tasks', 'Documents')
        page.find('md-tab-item', :text => "Tasks").click
        wait_all_requests
        wait(1)
        wait_all_requests
        expect(page).to have_selector('.md-active', :text => 'Tasks')
        expect(page).to have_content('ASSIGN WORKFLOW')
        page.find('md-tab-item', :text => "Documents").click
        wait_all_requests
        wait(1)
        wait_all_requests
        expect(page).to have_selector('.md-active', :text => 'Documents')
        expect(page).to have_content('Assign')
        page.find('md-tab-item', :text => I18n.t('onboard.home.toolbar.profile')).click
        wait_all_requests
        wait(1)
        wait_all_requests
        expect(page).to have_selector('.md-active', :text => I18n.t('onboard.home.toolbar.profile'))
        page.all('.section-right-approval-icons .icon-pencil').each do |el|
          el.trigger('click')
        end
        expect(page).to have_selector('[name="edit_personal_info"]')
        expect(page).to have_selector('[name="edit_additional_info"]')
        expect(page).to have_selector('[name="edit_private_info"]')
    end
    wait(2)
end

def verify_manager_team_permissions(selector)
    page.find('md-tab-item', :text =>('Team')).click
    wait_all_requests
    wait(2)
    page.find('.dataTable .user_full_name').click
    wait_all_requests
    if selector == 'no_access'
        expect(page).to have_no_selector('[name="edit_profile_info"]')
    else
      expect(page).to have_no_selector('[name="edit_profile_info"]')
    end

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
        expect(page).to have_no_selector('[name="edit_personal_info"]')
        expect(page).to have_no_selector('[name="edit_additional_info"]')
        expect(page).to have_no_selector('[name="edit_private_info"]')

    elsif selector == 'view_only'
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
        expect(page).to have_selector('.md-active', :text => I18n.t('onboard.home.toolbar.profile'))
        expect(page).to have_no_selector('[name="edit_personal_info"]')
        expect(page).to have_no_selector('[name="edit_additional_info"]')
        expect(page).to have_no_selector('[name="edit_private_info"]')

    elsif selector == 'view_edit'
        expect(plateform_menu_items).to include('Tasks', 'Documents')
        page.find('md-tab-item', :text => "Tasks").click
        wait_all_requests
        wait(1)
        wait_all_requests
        expect(page).to have_selector('.md-active', :text => 'Tasks')
        expect(page).to have_content('ASSIGN WORKFLOW')
        page.find('md-tab-item', :text => "Documents").click
        wait_all_requests
        wait(1)
        wait_all_requests
        expect(page).to have_selector('.md-active', :text => 'Documents')
        expect(page).to have_content('Assign')
        page.find('md-tab-item', :text => I18n.t('onboard.home.toolbar.profile')).click
        wait_all_requests
        wait(1)
        wait_all_requests
        page.all('.section-right-approval-icons .icon-pencil').each do |el|
          el.trigger('click')
        end
        expect(page).to have_selector('.md-active', :text => I18n.t('onboard.home.toolbar.profile'))
        expect(page).to have_selector('[name="edit_personal_info"]')
        expect(page).to have_selector('[name="edit_additional_info"]')
        expect(page).to have_selector('[name="edit_private_info"]')
    end

end

def login_with_sarah
    wait_all_requests
    wait(2)
    find('#user-menu .icon-chevron-down', visible: :all).click
    wait_all_requests
    wait(4)
    click_button(I18n.t('admin.header.menu.sign_out'))
    wait_all_requests
    wait(1)
    fill_in :email , with: 'sarah@test.com'
    fill_in :password , with: ENV['USER_PASSWORD']
    click_button('Sign In')
    wait_all_requests
end
