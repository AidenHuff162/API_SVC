def navigate_to_offboard
  wait_all_requests
  page.find(:css,'.md-locked-open').hover
  wait_all_requests
  wait_all_requests
  click_link('Dashboard')
  wait_all_requests
  find(".dashboard-header a", :text => I18n.t('admin.dashboard.overview.offboard_employee_button_txt')).trigger('click')
  wait_all_requests
end

def confirm_offboard_user
  choose_item_from_autocomplete('employee_name', "#{tim.first_name} #{tim.last_name}")
  choose_item_from_dropdown('termination_type','Voluntary')
  choose_item_from_dropdown('eligible_rehire','Yes')
  termination_date = (Date.today + 1.days).strftime("%m/%d/%Y")
  page.execute_script("$('.termination_date .md-datepicker-input').val('#{termination_date}').trigger('input')")
  wait_all_requests
  last_day_date = (Date.today + 1.days).strftime("%m/%d/%Y")
  page.execute_script("$('.last_day_date .md-datepicker-input').val('#{last_day_date}').trigger('input')")
  wait_all_requests
  # page.find('.terminate_employee').click
  choose_item_from_autocomplete_smart('location', location.name)
  choose_item_from_autocomplete_smart('employee_type','Full Time')
  choose_item_from_autocomplete_smart('team',team.name)
  wait_all_requests
  click_button I18n.t('admin.offboard.next_step')
end

def assign_workflows
  expect(page).to have_text('Assign Workflow')
  choose_first_item_from_dropdown('offboard_workflow')
  wait_all_requests
  choose_first_item_from_dropdown('offboard_workflow')
  wait_all_requests
  workstream_count = page.find("#workstream_count").text
  expect(workstream_count).to eq("2")
  tasks_count = page.find("#tasks_count").text
  expect(tasks_count).to eq("3")
  assignees_count = page.find("#assignees_count").text
  expect(assignees_count).to eq("3")
end

def skip_reassigining_step
  wait_all_requests
  click_button I18n.t('admin.offboard.reassign_next_step')
end

def reassign_team_member
  wait_all_requests
  expect(page).to have_text I18n.t('admin.offboard.reassign_manager_description',
                                     { name: tim.first_name, count: tim.managed_users.count }
                                  )
  click_button I18n.t('admin.offboard.reassign_bulk_manager')
  choose_item_from_autocomplete('select_another_manager', "#{sarah.first_name} #{sarah.last_name}")
  click_button I18n.t('admin.offboard.save')
  wait_all_requests
end

def reassign_active_tasks
  wait_all_requests
  expect(page).to have_text I18n.t('admin.offboard.reassign_active_tasks_description',
                                     { tasks_count:1, workstreams_count:1, name: tim.first_name }
                                  )
  find('#reassign_task').trigger('click')
  choose_item_from_autocomplete('task_reassign', "#{sarah.first_name} #{sarah.last_name}")
  click_button I18n.t('admin.offboard.reassign_individual_task')
  wait_all_requests
end

def reassign_template_tasks
  wait_all_requests
  expect(page).to have_text I18n.t('admin.offboard.reassign_template_tasks_description',
                                     { tasks_count:1, workstreams_count:1, name: tim.first_name }
                                    )
  find('#reassign_template_task').trigger('click')
  choose_item_from_autocomplete('task_reassign', "#{sarah.first_name} #{sarah.last_name}")
  click_button I18n.t('admin.offboard.reassign_individual_task')
  wait_all_requests
end

def skip_exit_finish_offboard_assign
  wait_all_requests
  click_button I18n.t('admin.offboard.skip_step_three')
  wait(3)
  expect(page).to have_css('.dataTable td')
  person_name = page.find('.dataTable tr:nth-child(1) td:nth-child(1)').text
  expect(person_name).to eq("#{tim.first_name} #{tim.last_name} #{tim.title}")
  final_date = page.find('.dataTable tr:nth-child(1) td:nth-child(2)').text
  expected_date = (Date.today + 1.days).strftime("%b %-1d")
  expect(final_date).to eq(expected_date)
  stage = page.find('.dataTable tr:nth-child(1) td:nth-child(5)').text
  expect(stage).to eq("Last Week")
  tasks = page.find('.dataTable tr:nth-child(1) td:nth-child(7)').text
  # expect(tasks).to eq("0 / 3")
  progress = page.find('.dataTable tr:nth-child(1) td:nth-child(8)').text
  expect(progress).to eq("0%")
end

def skip_exit_finish_offboard
  wait_all_requests
  click_button I18n.t('admin.offboard.skip_step_three')
  wait(3)
  expect(page).to have_css('.dataTable td')
  person_name = page.find('.dataTable tr:nth-child(1) td:nth-child(1)').text
  expect(person_name).to eq("#{tim.first_name} #{tim.last_name} #{tim.title}")
  final_date = page.find('.dataTable tr:nth-child(1) td:nth-child(2)').text
  expected_date = (Date.today + 1.days).strftime("%b %-1d")
  expect(final_date).to eq(expected_date)
  stage = page.find('.dataTable tr:nth-child(1) td:nth-child(5)').text
  expect(stage).to eq("Last Week")
  tasks = page.find('.dataTable tr:nth-child(1) td:nth-child(7)').text
  expect(tasks).to eq("0 / 1")
  progress = page.find('.dataTable tr:nth-child(1) td:nth-child(8)').text
  expect(progress).to eq("0%")
end

def initiate_offboarding
  find('span.ng-binding', text: 'INITIATE OFFBOARDING', visible: :all).click
  wait(5)
  expect(page.all('tbody tr').count).to eq(1)
end