def navigate_to_workspace(user_role)
	if user_role != 'employee'
		page.find('#user-menu button').click
		page.find('#workspace').click
		page.find('#create_new_workspace').click
		page.find('#workspace_name').send_keys('Test Workspace')
		choose_first_item_from_dropdown('workspace_avatar')
		choose_first_item_from_dropdown('workspace_timezone')
		page.find('#create_workspace').click
		wait_all_requests
		expect(page).to have_css('.account-name-holder')
		workspace_name = page.find('#workspace_name').text
		expect(workspace_name).to eq('Test Workspace')
	else
		page.find('#user-menu button').click
		expect(page).to have_no_selector('#workspace')
	end
end

def change_workspace_settings
	page.find('md-tab-item' , :text => I18n.t('workspace.sub_tabs.settings')).click
	wait_all_requests
	workspace_name = page.find('#settings_workspace_name').value
	expect(workspace_name).to eq('Test Workspace')
	page.find('#settings_workspace_name').set('Update Workspace Name')
	choose_item_from_dropdown('workspace_timezone','UTC -08:00 - Tijuana')
	page.find('#save_changes').click
end

def verify_workspace_settings
	wait_all_requests
	updated_workspace_name = page.find('#workspace_name').text
	expect(updated_workspace_name).to eq('Update Workspace Name')
end

def add_members_workspace
	page.find('md-tab-item' , :text => I18n.t('workspace.sub_tabs.members')).click
	wait_all_requests
	default_member = page.all('.dataTable tbody').length
	expect(default_member).to eq(1)
	page.find('.workspace-button').click
	wait_all_requests
	choose_item_from_autocomplete("workspace_members","#{peter.first_name} #{peter.last_name}")
	click_button I18n.t('workspace.members.buttons.invite')
end

def add_workspace_task
  wait_all_requests
  click_on('Add Task')
  wait_all_requests
  wait(1)
  task_name = find('#title .ql-editor p')
  task_name.send_keys('Test Task 1')
  find("md-select[name='due']").trigger('click')
  find('md-select-menu md-content md-option:nth-child(2) div').trigger('click')
  choose_item_from_dropdown('time-stamp', 'Before')
  choose_item_from_dropdown('assign-task', 'Workspace')
  choose_item_from_dropdown('workspace', 'Test Workspace')
  click_button 'Save'
  wait_all_requests
  expect(page).to have_selector('.md-toast-content .md-toast-text', text: 'Task Created')
  wait_all_requests
  page.find('.total-tasks', text: 'Total Tasks: 1')
  page.find('.tasks-count', text: 'Total Tasks: 1')
  task_count  = page.find('.workflow-count').text()
  expect(task_count).to eq('1')
  task_name = page.find('.added-task .quil-task-name').text()
  expect(task_name).to eq('Test Task 1')
  page.find('.task-due-date').text.should eq('2 days before')


  #add another task.

  click_button('Add Task')
  wait_all_requests
  wait(1)
  task_name = find('#title .ql-editor p')
  task_name.send_keys('Test Task 2')
  find("md-select[name='due']").trigger('click')
  find('md-select-menu md-content md-option:nth-child(4) div').trigger('click')
  choose_item_from_dropdown('time-stamp', 'After')
  choose_item_from_dropdown('assign-task', 'Workspace')
  choose_item_from_dropdown('workspace', 'Test Workspace')
  click_button 'Save'
  wait_all_requests
  task_name = page.find('.added-task:nth-child(2) .quil-task-name').text()
  expect(task_name).to eq('Test Task 2')
  page.find('.total-tasks', text: 'Total Tasks: 2')
  page.find('.tasks-count', text: 'Total Tasks: 2')
  page.find('.added-task:nth-child(2) .task-due-date').text.should eq('4 days after')

end

def assign_workspace_workflow
	click_link I18n.t('admin.header.nav.home')
  wait_all_requests
  page.find('md-tab-item', :text => I18n.t('admin.task.tasks')).trigger('click')
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

def verify_workspace_tasks
	page.find('#user-menu button').click
	page.find('#workspace').click
	page.find('#workspace_name').click
	wait(1)
	wait_all_requests
	#page.find('md-tab-item', :text => I18n.t('admin.task.tasks')).trigger('click')
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
  date = Date.today +  4.days
  task_date = date.strftime("%b %-1d")
  expect(task2_due_date).to eq("Due: #{task_date}")
end

def complete_workspace_task
	page.find('#open_task span').click
	wait_all_requests
	page.find('.assign_task .todo-item:nth-child(1) md-checkbox').trigger('click')
	wait_all_requests
	wait(1)
  page.find('.assign_task .todo-item:nth-child(1) md-checkbox').trigger('click')
  wait_all_requests
  wait(1)
  count_open_task =   page.find('#open_task span').text()
  expect(count_open_task).to eq('Incomplete (0)')
  count_complete_task =   page.find('#complete_task span').text()
  expect(count_complete_task).to eq('Complete (2)')
end
