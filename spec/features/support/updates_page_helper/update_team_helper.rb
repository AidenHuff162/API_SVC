def reassign_tasks_to_hire
  wait_all_requests
  find('.icon-checkbox-multiple-marked-outline').trigger("click")
  wait_all_requests
  expect(page).to have_selector('#workflows-header')
  find('.workflow-name').click
  wait_all_requests
  tasks_arr = find_all('.added-task')
  wait_all_requests
  for n in 0..tasks_arr.length - 1
    tasks_arr[n].trigger("click")
    task_name = find('#title .ql-editor p')
    task_name.send_keys('Update Test Task 1')
    choose_item_from_dropdown('time-stamp', 'On')
    choose_item_from_dropdown('assign-task', 'Hire')
    click_button 'Update Task'
    wait_all_requests
    expect(page).to have_selector('.md-toast-open-bottom')
  end

end

def navigate_to_team_tab
  navigate_to '/#/updates'
  find('md-tab-item', :text => I18n.t('onboard.home.toolbar.team')).trigger("click")
  expect(page).to have_selector(".dataTable")
end

def assign_tasks_to_team_member
  find(".purple-hover").trigger("click")
  wait_all_requests
  expect(page).to have_selector('#add_workflow_button')
  find('#add_workflow_button').trigger("click")
  wait_all_requests
  expect(page).to have_selector(".md-toolbar-tools")
  find('.workstream-list md-checkbox').trigger("click")
  click_button 'Next'
  click_button 'Next'
  page.find('.notify_task_owner_no').trigger("click")
  click_button 'Finish'
end

def validation_updates_page
  wait_all_requests
  navigate_to '/#/updates'
  wait_all_requests
  wait(2)
  update_activity_count = page.find("#team_counts").text().to_i
  find('md-tab-item', :text => I18n.t('onboard.home.toolbar.team')).trigger("click")
  wait_all_requests
  team_activity_count = find(".purple-hover").text().to_i
  expect(team_activity_count).to be == update_activity_count
end

def view_all
  navigate_to '/#/updates'
  wait_all_requests
  find('.click-to-action', :text => I18n.t('onboard.home.updates.pending_hires_panel.view-pending-hires-button')).trigger("click")
  wait_all_requests
  expect(page).to have_selector(".dataTable")
end
