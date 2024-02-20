def navigate_to_workflows
    wait_all_requests
    visit('/#/admin/activities/tasks')
    wait_all_requests
end

def add_new_workflow
    click_button 'Add Workflow'
    wait_all_requests
    wait(1)
    fill_in :name , with: 'Test Workflow'
    click_button 'Save'
    wait_all_requests
    wait_for_element('.added-workflow:nth-child(1) .workflow-name')
    find('.added-workflow:nth-child(1) .workflow-name').trigger('click')
    workflow_name = page.find('.added-workflow:nth-child(1) .workflow-name').text()
    expect(workflow_name).to eq('Test Workflow')
    page.find('.total-workflows', text: 'Total Workflows: 1')
end

def add_new_task
    wait_all_requests
    click_on('Add Task')
    wait_all_requests
    wait(1)
    task_name = find('#title .ql-editor p')
    task_name.send_keys('Test Task 1')
    choose_item_from_dropdown('due','12')
    choose_item_from_dropdown('time-stamp', 'Before')
    choose_item_from_dropdown('assign-task', 'Manager')
    click_button 'Save'
    wait_all_requests
    expect(page).to have_selector('.md-toast-content .md-toast-text', text: 'Task Created')
    wait_all_requests
    page.find('.total-tasks', text: 'Total Tasks: 1')
    page.find('.tasks-count', text: 'Total Tasks: 1')
    task_assign = page.find('.task_assign_manager').text()
    expect(task_assign).to eq('M')
    task_count  = page.find('.workflow-count').text()
    expect(task_count).to eq('1')
    task_name = page.find('.added-task .quil-task-name').text()
    expect(task_name).to eq('Test Task 1')
    page.find('.added-task:nth-child(1) .task-due-date').text.should eq('12 days before')
    #add another task.

    click_button('Add Task')
    wait_all_requests
    wait(1)
    task_name = find('#title .ql-editor p')
    task_name.send_keys('Test Task 2')
    choose_item_from_dropdown('due','14')
    choose_item_from_dropdown('time-stamp', 'After')
    choose_item_from_dropdown('assign-task', 'Hire')
    click_button 'Save'
    wait_all_requests
    task_name = page.find('.added-task:nth-child(2) .quil-task-name').text()
    expect(task_name).to eq('Test Task 2')
    task_assign = page.find('.task_assign_hire').text()
    expect(task_assign).to eq('H')
    page.find('.total-tasks', text: 'Total Tasks: 2')
    page.find('.tasks-count', text: 'Total Tasks: 2')
    page.find('.added-task:nth-child(2) .task-due-date').text.should eq('14 days after')
end

def update_task
    wait_all_requests
    page.find('.added-task:nth-child(1)').trigger('click')
    wait_all_requests
    wait(1)
    find('#title .ql-editor p').set('')
    task_name = find('#title .ql-editor p')
    task_name.send_keys('Update Test Task 1')
    choose_item_from_dropdown('time-stamp', 'On')
    choose_item_from_dropdown('assign-task', 'Buddy')
    click_button 'Update Task'
    wait_all_requests
    wait(1)
    task_name = page.find('.added-task:nth-child(1) .quil-task-name').text()
    expect(task_name).to eq('Update Test Task 1')
    task_assign = page.find('.task_assign_buddy').text()
    expect(task_assign).to eq('B')
    page.find('.total-tasks', text: 'Total Tasks: 2')
    page.find('.tasks-count', text: 'Total Tasks: 2')
    page.find('.task-due-date', text: 'On Date')
end

def delete_task
    page.find('.added-task:nth-child(1) .icon-delete').trigger('click')
    wait_all_requests
    click_button 'Yes'
    wait_all_requests
    wait(2)
    total_tasks = page.all('.added-task').length
    expect(total_tasks).to eq(1)
end


def add_second_workflow
    click_button 'Add Workflow'
    wait_all_requests
    wait(1)
    fill_in :name , with:'Test Workflow 2'
    click_button 'Save'
    wait_all_requests
    wait_for_element('.added-workflow:nth-child(2) .workflow-name')
    find('.added-workflow:nth-child(2) .workflow-name').trigger('click')
    workflow_name = page.find('.added-workflow:nth-child(2) .workflow-name').text()
    expect(workflow_name).to eq('Test Workflow 2')
    page.find('.total-workflows', text: 'Total Workflows: 2')
end

def add_newtask_in_secondworkflow
    wait_all_requests
    click_button('Add Task')
    wait_all_requests
    wait(1)
    task_name = find('#title .ql-editor p')
    task_name.send_keys('Test Task 1')
    choose_item_from_dropdown('due','2')
    choose_item_from_dropdown('time-stamp', 'Before')
    choose_item_from_dropdown('assign-task', 'Hire')
    click_button 'Save'
    wait_all_requests
    page.find('.total-tasks', text: 'Total Tasks: 2')
    page.find('.tasks-count', text: 'Total Tasks: 1')
    task_count  = page.find('.added-workflow:nth-child(2) .workflow-count').text()
    expect(task_count).to eq('1')
    task_name = page.find('.added-task .quil-task-name').text()
    expect(task_name).to eq('Test Task 1')
    page.find('.task-due-date', text: '2 days before')
end

def update_workflow_name
    page.find('.update_workflow_name').trigger('click')
    wait_all_requests
    wait(1)
    fill_in :name , with: 'Updated Workflow Name'
    click_button 'Save'
    wait_all_requests
    wait(1)
    workflow_name = page.find('#workstream_name').text()
    wait_all_requests
    expect(workflow_name).to eq('Updated Workflow Name')
end

def delete_workflow
    page.find('#workstream_action .icon-delete').trigger('click')
    click_button 'Yes'
    wait_all_requests
    page.find('.total-workflows', text: 'Total Workflows: 1')
end

def assign_workflow
    wait_all_requests
    page.find('.added-workflow:nth-child(1)').trigger('click')
    wait_all_requests
    click_button('Add Task')
    wait_all_requests
    wait(1)
    task_name = find('#title .ql-editor p')
    task_name.send_keys('Test Task 3')
    choose_item_from_dropdown('due','12')
    choose_item_from_dropdown('time-stamp', 'Before')
    choose_item_from_dropdown('assign-task', 'Hire')
    click_button 'Save'
    wait_all_requests
    click_button('Add Task')
    wait_all_requests
    wait(1)
    task_name = find('#title .ql-editor p')
    task_name.send_keys('Test Task 4')
    choose_item_from_dropdown('time-stamp', 'On')
    choose_item_from_dropdown('assign-task', 'Hire')
    click_button 'Save'
    wait_all_requests
    click_link I18n.t('admin.header.nav.home')
    wait_all_requests
    page.find('md-tab-item', text: 'Tasks').trigger('click')
    wait_all_requests
    click_button('Assign Workflow')
    wait_all_requests
    page.find('.workstream-list md-checkbox').trigger('click')
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
end

def verify_task_details
    #Check Task1 Details
    task1_owner_name = page.find('.assign_task .todo-item:nth-child(1) .task_owner_name').text()
    task1_due_date = page.find('.assign_task .todo-item:nth-child(1) .task_due_date').text()
    login_username = page.find('.login_username').text()
    expect(task1_owner_name).to eq(login_username)
    expect(task1_due_date).to eq("Due: Today")
    #Check Task2 Details
    task2_owner_name = page.find('.assign_task .todo-item:nth-child(2) .task_owner_name').text()
    task2_due_date = page.find('.assign_task .todo-item:nth-child(2) .task_due_date').text()
    login_username = page.find('.login_username').text()
    expect(task2_owner_name).to eq(login_username)
    expect(task2_due_date).to eq("Due: Today")
    #Check Task3 Details
    task3_owner_name = page.find('.assign_task .todo-item:nth-child(3) .task_owner_name').text()
    task3_due_date = page.find('.assign_task .todo-item:nth-child(3) .task_due_date').text()
    login_username = page.find('.login_username').text()
    expect(task3_owner_name).to eq(login_username)
    date = Date.today + 14.days
    task_date = date.strftime("%m/%d/%Y")
    expect(task3_due_date).to eq("Due: #{task_date}")
end

def count_overdue_tasks_before_task_completion
    page.find('.overdue_assign_task').click
    wait_all_requests
    total_task = page.all('.assign_task .todo-item').count
    expect(total_task).to eq(0)
end

def count_complete_tasks_before_task_completion
    page.find('.complete_assign_task').click
    wait_all_requests
    total_task = page.all('.assign_task .todo-item').count
    expect(total_task).to eq(0)
end

def count_incomplete_tasks_before_task_completion
    page.find('.incomplete_assign_task').click
    wait_all_requests
    total_task = page.all('.assign_task .todo-item').count
    expect(total_task).to eq(3)
end

def change_task_due_date
    wait_all_requests
    wait(1)
    page.find(".assign_task .todo-item:nth-child(3) .icon-dots-vertical").click
    page.find(".md-active md-menu-item", :text => I18n.t('onboard.home.tasks.change_date')).click
    date = Date.today + 20.days
    page.execute_script("$('.md-datepicker-input').val('#{date}')")
    page.execute_script("$('.md-datepicker-input').trigger('input')")
    wait_all_requests
    click_button('Save')
    wait_all_requests
    wait(2)
    task_due_date = page.find('.assign_task .todo-item:nth-child(3) .task_due_date').text()
    date = Date.today + 20.days
    task_date = date.strftime("%m/%d/%Y")
    expect(task_due_date).to eq("Due: #{task_date}")
end

def complete_assign_tasks
    #all total tasks count
    wait_all_requests
    all_task = page.find('.all_assign_task span').text()
    expect(all_task).to eq('All (3)')
    incomplete_task = page.find('.incomplete_assign_task span').text()
    expect(incomplete_task).to eq('Incomplete (3)')
    complete_task = page.find('.complete_assign_task span').text()
    expect(complete_task).to eq('Complete (0)')
    page.find('.all_assign_task').click
    wait_all_requests
    #complete all tasks and check count
    total_task = page.all('.assign_task .todo-item').count
    expect(total_task).to eq(3)
    page.find('.assign_task .todo-item:nth-child(1) md-checkbox').trigger('click')
    wait_all_requests
    all_task = page.find('.all_assign_task span').text()
    expect(all_task).to eq('All (3)')
    incomplete_task = page.find('.incomplete_assign_task span').text()
    wait_all_requests
    expect(incomplete_task).to eq('Incomplete (2)')
    complete_task = page.find('.complete_assign_task span').text()
    expect(complete_task).to eq('Complete (1)')
    page.find('.assign_task .todo-item:nth-child(1) md-checkbox').trigger('click')
    wait_all_requests
    page.find('.assign_task .todo-item:nth-child(1) md-checkbox').trigger('click')
    wait_all_requests
    all_task = page.find('.all_assign_task span').text()
    expect(all_task).to eq('All (3)')
    incomplete_task = page.find('.incomplete_assign_task span').text()
    expect(incomplete_task).to eq('Incomplete (2)')
    complete_task = page.find('.complete_assign_task span').text()
    expect(complete_task).to eq('Complete (1)')
end

def count_overdue_tasks_after_task_completion
    page.find('.overdue_assign_task').trigger('click')
    wait_all_requests
    total_task = page.all('.assign_task .todo-item').count
    expect(total_task).to eq(0)
end

def count_complete_tasks_after_task_completion
    wait_all_requests
    page.find('.complete_assign_task').trigger('click')
    wait_all_requests
    total_task = page.all('.assign_task .todo-item').count
    expect(total_task).to eq(1)
end

def count_incomplete_tasks_after_task_completion
    page.find('.incomplete_assign_task').trigger('click')
    wait_all_requests
    total_task = page.all('.assign_task .todo-item').count
    expect(total_task).to eq(2)
end
