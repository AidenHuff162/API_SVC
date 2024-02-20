
def navigate_to_updates
    wait_all_requests
    navigate_to "/#/updates"
    wait(2)
end

def navigate_to_tasks
    page.find('md-tab-item', text:'Tasks').trigger('click')
    wait_all_requests
    wait(1)
end

def create_user_profile_for_update_page
    wait_all_requests
   fill_in :first_name, with: user_attributes[:first_name]
    fill_in :last_name, with: user_attributes[:last_name]
    fill_in :personal_email, with: 'user@gmail.com'

    fill_in :email, with: 'user@ymail.com'
    wait_all_requests
    choose_item_from_autocomplete('job_title', "Head of Operations")
    scroll_to page.find('#date', visible: false)

    page.find('#date .md-datepicker-triangle-button').trigger('click')
    wait_all_requests
    page.find('.md-focus').trigger('click')
    wait(1)

    choose_item_from_autocomplete('employee_type','Full Time')
    choose_item_from_autocomplete('manager', "#{sarah.first_name} #{sarah.last_name}")
   

    wait_all_requests
    click_on I18n.t('log_in.save')
    wait(2)

    navigate_to "/#/pending_hire"
    wait_all_requests

    click_button ("EXIT")
    wait_all_requests

    navigate_to "/#/updates"
    wait_all_requests
    click_button("VIEW ALL")
    wait_all_requests

    page.has_content?('Pending hires')

end



def assign_workflow_for_my_activities
    wait_all_requests
    visit('/#/admin/activities/tasks')
    wait_all_requests
    #############Add new Workflows###########
    wait_all_requests
    wait(3)
    click_button 'Add Workflow'
    wait_all_requests
    fill_in :name , with: 'Test Workflow'
    click_button 'Save'
    wait_all_requests
    wait_for_element('.added-workflow:nth-child(1) .workflow-name')
    find('.added-workflow:nth-child(1) .workflow-name').trigger('click')
    workflow_name = page.find('.added-workflow:nth-child(1) .workflow-name').text()
    page.find('.total-workflows', text: 'Total Workflows: 1')
    ##########Add new tasks#######################
    wait_all_requests
    click_on('Add Task')
    wait_all_requests
    wait(1)
    task_name = find('#title .ql-editor p')
    task_name.send_keys('Test Task 1')
    choose_item_from_dropdown('due','2')
    choose_item_from_dropdown('time-stamp', 'Before')
    choose_item_from_dropdown('assign-task', 'Hire')
    click_button 'Save'
    wait_all_requests
    expect(page).to have_selector('.md-toast-content .md-toast-text', text: 'Task Created')
    wait_all_requests
    click_on('Add Task')
    wait_all_requests
    wait(1)
    task_name = find('#title .ql-editor p')
    task_name.send_keys('Test Task 2')
    choose_item_from_dropdown('due','2')
    choose_item_from_dropdown('time-stamp', 'After')
    choose_item_from_dropdown('assign-task', 'Hire')
    click_button 'Save'
    wait_all_requests
    expect(page).to have_selector('.md-toast-content .md-toast-text', text: 'Task Created')
    wait_all_requests
    click_on('Add Task')
    wait_all_requests
    wait(1)
    task_name = find('#title .ql-editor p')
    task_name.send_keys('Test Task 3')
    choose_item_from_dropdown('time-stamp', 'On')
    choose_item_from_dropdown('assign-task', 'Hire')
    click_button 'Save'
    wait_all_requests
    expect(page).to have_selector('.md-toast-content .md-toast-text', text: 'Task Created')
    wait_all_requests
    click_link I18n.t('admin.header.nav.home')
    wait_all_requests
    page.find('md-tab-item', text: 'Tasks').trigger('click')
    wait_all_requests
    click_button('Assign Workflow')
    wait_all_requests
    page.execute_script("$('md-checkbox:first .md-ink-ripple').click()")
    wait_all_requests
    click_button 'Next'
    wait_all_requests
    click_button 'Next'
    page.find('.md-datepicker-expand-triangle').trigger('click')
    wait_all_requests
    page.find('.md-focus').trigger('click')
    wait_all_requests
    wait(2)

    page.find('.notify_task_owner_no').trigger('click')
    wait_all_requests
    click_button 'Finish'
    wait_all_requests
    wait(2)

end

def assign_manager_for_my_team_panel
    wait_all_requests
    # click_button('LEARN MORE')
    # wait_all_requests
    # page.find('.dataTable tbody tr:nth-child(1) td:nth-child(1)').trigger('click')
    # wait_all_requests
    # # choose_item_from_autocomplete('manager','Sarah Salem')
    # wait_all_requests
    # page.find('.md-toolbar-tools .icon-close').trigger('click')
    # wait_all_requests
end

