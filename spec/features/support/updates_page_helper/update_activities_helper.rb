def navigate_to_tasks_tab
  wait(2)
  wait_all_requests
  page.find('md-tab-item' ,:text => 'Tasks').click
end

def assign_workflow_for_myactivities
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

def request_pto
  navigate_to '/#/updates'
  wait 1
  wait_all_requests
  find('md-tab-item', :text => I18n.t('onboard.home.toolbar.team')).trigger("click")
  wait_all_requests
  find(".purple-hover").trigger("click")
  wait 1
  find('md-tab-item', :text => 'Time Off').trigger("click")
  wait_all_requests
  find('button', :text => 'REQUEST TIME OFF').trigger("click")
  wait_all_requests
  click_button 'SUBMIT'
end

def activities_validation
  # expect(page).to have_content('You have 7 activities to complete')
  # expect(page).to have_content('1 documents to complete')
  expect(page).to have_content('5 tasks to complete')
  expect(page).to have_content('0 tasks are overdue')
  # expect(page).to have_content('1 leave requests to approve')
end


def expand_activities_panel
   wait_all_requests
   page.find('expansion-panel[title="My activities"] .collapsed-div').trigger('click')
   wait_all_requests
   wait(1)
end

def validate_myactivities_view
   # view_documents
   navigate_to_updates
   view_tasks
   navigate_to_updates
   view_overdue_tasks
   navigate_to_updates
   # view_leave_requests
end


def view_documents
   wait_all_requests
   page.find('expansion-panel[title="My activities"]  #check_documents').trigger('click')
   wait_all_requests
   expect(page).to have_selector('.md-active', :text => 'Documents')
   expect(page).to have_content('Showing 1 to 1 of 1')
end

def view_tasks
   wait_all_requests
   page.find('expansion-panel[title="My activities"] .collapsed-div').trigger('click')
   page.find('expansion-panel[title="My activities"]  #check_complete_tasks').trigger('click')
   wait_all_requests
   expect(page).to have_selector('.md-active', :text => 'Tasks')
   expect(page).to have_content('Incomplete (5)')
end

def view_overdue_tasks
   wait_all_requests
   page.find('expansion-panel[title="My activities"] .collapsed-div').trigger('click')
   page.find('expansion-panel[title="My activities"]  #check_overdue_tasks').trigger('click')
   wait_all_requests
   expect(page).to have_selector('.md-tab.md-ink-ripple', :text => 'Tasks')
   expect(page).to have_content('0 tasks are overdue')
end

def view_leave_requests
   wait_all_requests
   page.find('expansion-panel[title="My activities"] .collapsed-div').trigger('click')
   page.find('expansion-panel[title="My activities"]  #check_leave_requests').trigger('click')
   wait_all_requests
   expect(page).to have_selector('.md-active', :text => 'Team')
end