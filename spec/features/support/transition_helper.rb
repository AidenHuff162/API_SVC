def navigate_to_onboarding_user_tasks
	wait_all_requests
	navigate_to "/#/tasks/"+peter.id.to_s
	wait(2)
end

def assign_documents
	page.find('.drop_button').trigger('click')
	wait_all_requests
	click_on ('Request File Upload')

	wait_all_requests
	click_on ('New')

	wait_all_requests
  expect(page).to have_text('Assign New Upload Request Document')

	wait_all_requests
	fill_in :title, with:'Upload document'
	fill_in :description, with:'Upload request'

	wait_all_requests
	find('.assign-upload-document').trigger('click')

	wait_all_requests
	expect(page).to have_text('Upload document')

	wait_all_requests
	page.find('.drop_button').trigger('click')

	wait_all_requests
	click_on ('Request File Upload')

	wait_all_requests
	click_on ('New')

	wait_all_requests
	expect(page).to have_text('Assign New Upload Request Document')

	wait_all_requests
	fill_in :title, with:'Upload document1'
	fill_in :description, with:'Upload request'

	wait_all_requests
	find('.assign-upload-document').trigger('click')

	wait_all_requests
	expect(page).to have_text('Upload document1')
end


def navigate_to_onboarding_user_documents
	wait_all_requests
	navigate_to "/#/documents/"+peter.id.to_s
	wait(2)
end

def navigate_to_offboarding_user_documents
	wait_all_requests
	navigate_to "/#/documents/"+tim.id.to_s
	wait(2)
end

def navigate_to_active_user_documents
	wait_all_requests
	navigate_to "/#/documents/"+nick.id.to_s
	expect(page).to have_content("Drag and drop your files")
	expect(page).not_to have_content("DOWNLOAD ALL")
	wait(2)
end

def navigate_to_offoarding_user_tasks
	wait_all_requests
	navigate_to "/#/tasks/"+tim.id.to_s
	wait(2)
end

def navigate_to_active_user_tasks
	wait_all_requests
	navigate_to "/#/tasks/"+nick.id.to_s
	expect(page).to have_content("No tasks found")
	wait(2)
end

def add_task
	wait_all_requests
	click_button ('ADD TASK')
	wait_all_requests
	task_name = find('#title .ql-editor p')
	wait_all_requests
	task_name.send_keys('Test Task 1')
	wait_all_requests
	click_button 'Save'
	wait_all_requests
	wait(3)
	expect(page).to have_content('Incomplete (1)')
	expect(page).to have_content('Complete (0)')
	expect(page).to have_content('Overdue (0)')
end

def add_overdue_task
	wait_all_requests
	page.find("#add_task_button").trigger('click')
	wait_all_requests
	task_name = find('#title .ql-editor p')
	task_name.send_keys('Test Task 2')
	due_date = (Date.today-7.days).strftime("%m/%d/%Y")
	page.execute_script("$('.md-datepicker-input').val('#{due_date}').trigger('input')")
	wait_all_requests
	click_button 'Save'
	wait_all_requests
	wait(2)
	expect(page).to have_content('Incomplete (2)')
	expect(page).to have_content('Complete (0)')
	expect(page).to have_content('Overdue (1)')
end

def assign_manager_task
	wait_all_requests
	expect(page).to have_content('ASSIGN WORKFLOW')
	page.find('#add_workflow_button').trigger('click')
	wait_all_requests
	page.find('.workstream-list .md-icon:nth-child(1)').trigger('click')
	wait_all_requests
	page.find('.sapling-primary.md-button:nth-child(3)').trigger('click')
	wait_all_requests
	page.find('.sapling-primary.md-button:nth-child(3)').trigger('click')
	wait_all_requests
	page.find('.sapling-primary.md-button:nth-child(3)').trigger('click')
	wait_all_requests
end

def navigate_to_transition_dashboard
	wait_all_requests
	navigate_to "/#/admin/dashboard/transition"
	wait(2)
end

def search_onboarding_user_in_transition_dashboard
	wait_all_requests
	fill_in :transition_search, with:'peter'
	wait(2)
	team_members = find("#team_members_count").text
	expect(team_members).to eq("0")
	open_activities = find("#open_activities_count").text
	expect(open_activities).to eq("0")
	overdue_activities = find("#overdue_activities_count").text
	expect(overdue_activities).to eq("0")
	expect(page).to have_content("No Team Members Found")
	wait_all_requests
end

def search_offboarding_user_in_transition_dashboard
	wait_all_requests
	fill_in :transition_search, with:'tim'
	wait(2)
	expect(page).to have_content("No Team Members Found")
	wait_all_requests
end

def search_active_user_in_transition_dashboard_and_verify_data_for_tasks
	wait_all_requests
	fill_in :transition_search, with:'nick'
	wait(2)
	team_members = find("#team_members_count").text
	expect(team_members).to eq("1")
	open_activities = find("#open_activities_count").text
	expect(open_activities).to eq("2")
	overdue_activities = find("#overdue_activities_count").text
	expect(overdue_activities).to eq("1")
	expect(page).to have_css('.dataTable td')
	person_name = page.find('.dataTable tr:nth-child(1) td:nth-child(1)').text
	expect(person_name).to eq("#{nick.first_name} #{nick.last_name} #{nick.title}")
	key_date = page.find('.dataTable tr:nth-child(1) td:nth-child(2)').text
	expect(key_date).to eq(nick.start_date.strftime("%b %-1d"))
	department = page.find('.dataTable tr:nth-child(1) td:nth-child(3)').text
	expect(department).to eq(nick.team.to_s)
	location = page.find('.dataTable tr:nth-child(1) td:nth-child(4)').text
	expect(location).to eq(nick.location.to_s)
	stage = page.find('.dataTable tr:nth-child(1) td:nth-child(5)').text
	expect(stage).to eq('7th Year')
	tasks = page.find('.dataTable tr:nth-child(1) td:nth-child(7)').text
	expect(tasks).to eq('0 / 2')
	progress = page.find('.dataTable tr:nth-child(1) td:nth-child(8)').text
	expect(progress).to eq('0%')
end

def search_active_user_in_transition_dashboard_and_verify_data_for_documents
	wait_all_requests
	fill_in :transition_search, with:'nick'
	wait(2)
	team_members = find("#team_members_count").text
	expect(team_members).to eq("1")
	expect(page).to have_css('.dataTable td')
	person_name = page.find('.dataTable tr:nth-child(1) td:nth-child(1)').text
	expect(person_name).to eq("#{nick.first_name} #{nick.last_name} #{nick.title}")
	key_date = page.find('.dataTable tr:nth-child(1) td:nth-child(2)').text
	expect(key_date).to eq(nick.start_date.strftime("%b %-1d"))
	department = page.find('.dataTable tr:nth-child(1) td:nth-child(3)').text
	expect(department).to eq(nick.team.to_s)
	location = page.find('.dataTable tr:nth-child(1) td:nth-child(4)').text
	expect(location).to eq(nick.location.to_s)
	stage = page.find('.dataTable tr:nth-child(1) td:nth-child(5)').text
	expect(stage).to eq('7th Year')
	documents = page.find('.dataTable tr:nth-child(1) td:nth-child(6)').text
	expect(documents).to eq('0 / 2')
	tasks = page.find('.dataTable tr:nth-child(1) td:nth-child(7)').text
	expect(tasks).to eq('')
	progress = page.find('.dataTable tr:nth-child(1) td:nth-child(8)').text
	expect(progress).to eq('0%')
 end

 def verify_documents_after_deletion
	wait_all_requests
	fill_in :transition_search, with:'nick'
	wait(2)
	team_members = find("#team_members_count").text
	expect(team_members).to eq("1")
	expect(page).to have_css('.dataTable td')
	person_name = page.find('.dataTable tr:nth-child(1) td:nth-child(1)').text
	expect(person_name).to eq("#{nick.first_name} #{nick.last_name} #{nick.title}")
	key_date = page.find('.dataTable tr:nth-child(1) td:nth-child(2)').text
	expect(key_date).to eq(nick.start_date.strftime("%b %-1d"))
	department = page.find('.dataTable tr:nth-child(1) td:nth-child(3)').text
	expect(department).to eq(nick.team.to_s)
	location = page.find('.dataTable tr:nth-child(1) td:nth-child(4)').text
	expect(location).to eq(nick.location.to_s)
	stage = page.find('.dataTable tr:nth-child(1) td:nth-child(5)').text
	expect(stage).to eq('7th Year')
	documents = page.find('.dataTable tr:nth-child(1) td:nth-child(6)').text
	expect(documents).to eq('0 / 1')
	tasks = page.find('.dataTable tr:nth-child(1) td:nth-child(7)').text
	expect(tasks).to eq('')
	progress = page.find('.dataTable tr:nth-child(1) td:nth-child(8)').text
	expect(progress).to eq('0%')
  end

def navigate_to_active_user_assigned_tasks
	wait_all_requests
	navigate_to "/#/tasks/"+nick.id.to_s
	expect(page).to have_content('Incomplete (2)')
	expect(page).to have_content('Complete (0)')
	expect(page).to have_content('Overdue (1)')
	wait(2)
end

def navigate_to_active_user_assigned_documents
	wait_all_requests
	navigate_to "/#/documents/"+nick.id.to_s
	expect(page).to have_content("Drag and drop your files")
	expect(page).to have_content("DOWNLOAD ALL")
	expect(page).to have_content('Incomplete')
	expect(page).not_to have_content('Complete')
	wait(2)
end


def complete_task
	page.find('.assign_task .todo-item:nth-child(1) md-checkbox').trigger('click')
	wait_all_requests
	wait(3)
	expect(page).to have_content('Incomplete (1)')
	expect(page).to have_content('Complete (1)')
	expect(page).to have_content('Overdue (0)')
end

def delete_document
	expect(page).to have_content('Upload document1')
	wait_all_requests
	find('.odd [aria-label="options"]').trigger('click')
	wait_all_requests
	click_on 'Delete'
	wait_all_requests
	expect(page).to have_content('Are you sure you want to delete this document?')
	click_button('Yes')
	wait_all_requests
	expect(page).not_to have_content('Upload document1')
	expect(page).to have_content('Upload document')
end

def verify_tasks_after_completion
	wait_all_requests
	fill_in :transition_search, with:'nick'
	wait(2)
	team_members = find("#team_members_count").text
	expect(team_members).to eq("1")
	open_activities = find("#open_activities_count").text
	expect(open_activities).to eq("1")
	overdue_activities = find("#overdue_activities_count").text
	expect(overdue_activities).to eq("0")
	expect(page).to have_css('.dataTable td')
	person_name = page.find('.dataTable tr:nth-child(1) td:nth-child(1)').text
	expect(person_name).to eq("#{nick.first_name} #{nick.last_name} #{nick.title}")
	key_date = page.find('.dataTable tr:nth-child(1) td:nth-child(2)').text
	expect(key_date).to eq(nick.start_date.strftime("%b %-1d"))
	department = page.find('.dataTable tr:nth-child(1) td:nth-child(3)').text
	expect(department).to eq(nick.team.to_s)
	location = page.find('.dataTable tr:nth-child(1) td:nth-child(4)').text
	expect(location).to eq(nick.location.to_s)
	stage = page.find('.dataTable tr:nth-child(1) td:nth-child(5)').text
	expect(stage).to eq('7th Year')
	tasks = page.find('.dataTable tr:nth-child(1) td:nth-child(7)').text
	expect(tasks).to eq('1 / 2')
	progress = page.find('.dataTable tr:nth-child(1) td:nth-child(8)').text
	expect(progress).to eq('50%')
  end


 def transition_action_complete_all_tasks
	wait_all_requests
	page.find('[name="action_button"]').trigger('click')
	wait_all_requests
	click_button I18n.t('admin.dashboard.datatables.complete_activity_button')
	wait_all_requests
	wait(10)
	team_members = find("#team_members_count").text
	expect(team_members).to eq("0")
	open_activities = find("#open_activities_count").text
	expect(open_activities).to eq("0")
	overdue_activities = find("#overdue_activities_count").text
	expect(overdue_activities).to eq("0")
	expect(page).to have_content("No Team Members Found")
 end

 def transition_action_complete_all_tasks_for_documents
	wait_all_requests
	page.find('[name="action_button"]').trigger('click')
	wait_all_requests
	click_button I18n.t('admin.dashboard.datatables.complete_activity_button')
	expect(page).to have_text I18n.t("admin.company.general.complete_activities", {name:nick.first_name})
 end


 def transition_action_delete_hire
	wait_all_requests
	page.find('[name="action_button"]').trigger('click')
	wait_all_requests
	click_button I18n.t('admin.dashboard.datatables.delete_employee')
	wait_all_requests
	expect(page).to have_content("Are you sure you want to delete this user?")
	click_button('Yes')
	wait_all_requests
	wait(5)
	team_members = find("#team_members_count").text
	expect(team_members).to eq("0")
	open_activities = find("#open_activities_count").text
	expect(open_activities).to eq("0")
	overdue_activities = find("#overdue_activities_count").text
	expect(overdue_activities).to eq("0")
	expect(page).to have_content("No Team Members Found")
 end
