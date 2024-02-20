def navigate_to_home
	wait_all_requests
	visit('/#/profile')
end

def navigate_to_task_from_home
	find('md-tabs-canvas md-tab-item', text: "Tasks").trigger("click")
end

def add_new_task_for_calendar
	wait_all_requests
  click_on('Add Task')
  wait_all_requests
  wait(1)
  task_name = find('#title .ql-editor p')
  task_name.send_keys('Test Task 1')
  choose_item_from_dropdown('time-stamp', 'On')
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
  page.find('.task-due-date', text: 'On Date')

  #add another task.

  click_button('Add Task')
  wait_all_requests
  wait(1)
  task_name = find('#title .ql-editor p')
  task_name.send_keys('Test Task 2')
  choose_item_from_dropdown('time-stamp', 'On')
  choose_item_from_dropdown('assign-task', 'Hire')
  click_button 'Save'
  wait_all_requests
  task_name = page.find('.added-task:nth-child(2) .quil-task-name').text()
  expect(task_name).to eq('Test Task 2')
  task_assign = page.find('.task_assign_hire').text()
  expect(task_assign).to eq('H')
  page.find('.total-tasks', text: 'Total Tasks: 2')
  page.find('.tasks-count', text: 'Total Tasks: 2')

end

def assigning_workflow
  wait_all_requests
  click_button('Assign Workflow')
  wait_all_requests
  page.find('.workstream-list md-checkbox').trigger('click')
  wait_all_requests
  click_button('Next')
  wait_all_requests
  click_button('Next')
  page.find('.md-datepicker-expand-triangle').trigger('click')
  wait_all_requests
  page.find('.md-focus').trigger('click')
  wait_all_requests
  page.find('.notify_task_owner_no').trigger('click')
  wait_all_requests
  click_button 'Finish'
  wait_all_requests

end

def check_task_on_calendar
	wait(2)
	expect(page).to have_selector('.custom-calendar')
end

def navigate_to_calendar
	wait_all_requests
	find('md-tab-item', :text => I18n.t("admin.settings.roles.visibility_calendar")).trigger("click")
end


def navigate_to_company_settings
	wait_all_requests
	visit('/#/admin/company/general')
	wait_all_requests
end

def navigate_to_holidays_tab
	wait(6)
	find('.border-line-item', :text => I18n.t("admin.company_section_menu.holidays")).trigger("click")
	wait_all_requests
end

def check_holidays_on_calendar
  wait_all_requests
  wait(10)
	count_holidays = find_all('[style="background-color:#448A6B;border-color:#448A6B"]').count
  if count_holidays == 0
		find('.icon-chevron-right').trigger('click')
		wait_all_requests
	end
	expect(page).to have_selector('[style="background-color:#448A6B;border-color:#448A6B"]')
end

def create_new_holiday_single_date(no_of_days,holiday_name)
	wait_all_requests
	find('.add-new-holiday', :text => I18n.t("admin.create_company_holiday")).trigger("click")
	wait_all_requests
	fill_in :holiday_name , with:holiday_name
	wait_all_requests
	find('.md-datepicker-triangle-button').trigger("click")
	wait_all_requests
	expect(page).to have_selector('.md-calendar-day-header')
	holiday_date = (Date.today + no_of_days.to_i.days).strftime("%m/%d/%Y")
	page.execute_script("$('.holiday-begin-date input').val('#{holiday_date}').trigger('input')")
	wait_all_requests
	find('.md-raised', :text => I18n.t('admin.save_button')).trigger("click")
	choose_item_from_dropdown("holiday_year", Date.strptime(holiday_date, "%m/%d/%Y").year)
	wait(3)
	expect(page).to have_selector('.clickable', :text => holiday_name)
	wait_all_requests
end

def create_holiday_multiple_date(holiday_name)
	wait_all_requests
	find('.add-new-holiday', :text => I18n.t("admin.create_company_holiday")).trigger("click")
	wait_all_requests
	fill_in :holiday_name , with:holiday_name
	find('[name="multiple_dates"]').trigger("click")
	expect(page).to have_selector('[name="end_date"]')
	find('.holiday-begin-date .md-datepicker-triangle-button').trigger("click")
	wait_all_requests
	expect(page).to have_selector('.md-calendar-day-header')
	wait_all_requests
	find('[name="end_date"] .md-datepicker-triangle-button').trigger("click")
	wait_all_requests
	expect(page).to have_selector('.md-calendar-day-header')
	starting_date = (Date.today + 2.days).strftime("%m/%d/%Y")
	finish_date = (Date.today + 4.days).strftime("%m/%d/%Y")
	page.execute_script("$('.holiday-begin-date input').val('#{starting_date}').trigger('input')")
	wait(1)
	page.execute_script("$('[name=end_date] input').val('#{finish_date}').trigger('input')")
	wait(1)
	find('.md-raised', :text => I18n.t('admin.save_button')).trigger("click")
	choose_item_from_dropdown("holiday_year", Date.strptime(starting_date, "%m/%d/%Y").year)
	wait(3)
	expect(page).to have_selector('.clickable', :text => holiday_name)
	wait_all_requests
end

def adding_birthday
	find('md-tab-item', :text => I18n.t("board.activities.headings.employee_record")).trigger("click")
	wait_all_requests
	date = Date.parse('01/02/1997').strftime("%m/%d/%Y")
	page.execute_script("$('.md-datepicker-input-container input').val('#{date}').trigger('input')")
	wait_all_requests
	page.execute_script("$[button:contains('Save'):enabled].click()")
	wait_all_requests
end

def check_birthdays_on_calendar
	wait(4)
	for n in 1..12
		wait(2)
		wait_all_requests
		count_birthdays = find_all('[style="background-color:#4E4DE3;border-color:#4E4DE3"]').count
		wait_all_requests
		if count_birthdays > 0
			break
		else
			find('.icon-chevron-right').trigger('click')
			wait_all_requests
		end
	end

end