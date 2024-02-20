def navigate_to_groups
  wait_all_requests
  page.find(:css,'.md-locked-open').hover
  wait_all_requests

  click_link('Groups')
  wait(3)
  expect(page).to have_text I18n.t('admin.groups.title_hint')
  wait_all_requests
end

def add_new_department

  find('.sapling-secondary').trigger('click')
  wait_all_requests
  expect(page).to have_text('New Group')
  within '.edit-owner-dialog-wrapper' do
    expect(page).to have_content('Departments')
  end

  fill_in I18n.t('admin.groups.group_dialog.name'), with: "Data Science"
  wait_all_requests
  click_button 'Save'

  wait_all_requests
  expect(page).to have_css('.dataTable td')
  tr = page.find('.dataTable tr', text: 'Data Science')
  active_members = tr.find('td:nth-child(2)').text
  expect(active_members).to eq('0')

  inactive_members = tr.find('td:nth-child(3)').text
  expect(inactive_members).to eq('0')
end

def add_new_location
  find('button.dashboard-menu-btn').trigger('click')
  wait_all_requests
  click_on 'Locations'
  wait_all_requests


  find('.sapling-secondary').trigger('click')
  wait_all_requests

  expect(page).to have_text('New Group')
  within '.edit-owner-dialog-wrapper' do
    expect(page).to have_content('Locations')
  end

  fill_in I18n.t('admin.groups.group_dialog.name'), with: "Kashmir"
  wait_all_requests
  click_button 'Save'
  wait_all_requests
  
  expect(page).to have_css('.dataTable td')
  tr = page.find('.dataTable tr', text: 'Kashmir')
  active_members = tr.find('td:nth-child(2)').text
  expect(active_members).to eq('0')

  inactive_members = tr.find('td:nth-child(3)').text
  expect(inactive_members).to eq('0')
end


def set_active_user_department_and_location
  navigate_to "/#/role/"+nick.id.to_s
  wait_all_requests
  expect(page).to have_text('Role Information')

  within find(".white-bg", text: ('Role Information')) do
    find("#update_custom_table").trigger('click')
  end
  wait_all_requests

  expect(page).to have_text('Change Role Information')
  choose_item_from_dropdown('department','Data Science')

  choose_item_from_dropdown('location','Kashmir')
  fill_in 'job_title', with: 'SE'
  click_button 'Submit'
  wait_all_requests
end

def set_inactive_user_department_and_location
  navigate_to "/#/role/"+peter.id.to_s
  wait_all_requests
  expect(page).to have_text('Role Information')
  within find(".white-bg", text: ('Role Information')) do
    find("#update_custom_table").trigger('click')
  end
  wait_all_requests

  expect(page).to have_text('Change Role Information')
  choose_item_from_dropdown('department','Data Science')

  choose_item_from_dropdown('location','Kashmir')
  fill_in 'job_title', with: 'SE'
  click_button 'Submit'
  wait_all_requests
end

def verify_active_and_inactive_count_of_department
  expect(page).to have_css('.dataTable td')
  expect(page).to have_text('Data Science')

  tr = page.find('.dataTable tr', text: 'Data Science')
  active_members = tr.find('td:nth-child(2)').text
  expect(active_members).to eq('1')
  inactive_members = tr.find('td:nth-child(3)').text
  expect(inactive_members).to eq('1')
end

def verify_active_and_inactive_count_of_location
  find('button.dashboard-menu-btn').trigger('click')
  wait_all_requests
  click_on 'Locations'
  wait_all_requests

  expect(page).to have_css('.dataTable td')
  expect(page).to have_text('Kashmir')
  tr = page.find('.dataTable tr', text: 'Kashmir')
  active_members = tr.find('td:nth-child(2)').text
  expect(active_members).to eq('1')

  inactive_members = tr.find('td:nth-child(3)').text
  expect(inactive_members).to eq('1')
end

def disable_department_and_location_toggle
  tr = page.find('.dataTable tr', text: 'Kashmir')
  tr.find('.md-bar').trigger('click')
  wait_all_requests
  find('button.dashboard-menu-btn').trigger('click')
  wait_all_requests

  click_on 'Departments'
  expect(page).to have_css('.dataTable td')
  expect(page).to have_text('Data Science')

  tr = page.find('.dataTable tr', text: 'Data Science')
  tr.find('.md-bar').trigger('click')
  wait_all_requests
end

def verify_department_and_location_toggle_for_active_user
  navigate_to "/#/role/"+tim.id.to_s
  wait_all_requests
  expect(page).to have_text('Role Information')

  within find(".white-bg", text: ('Role Information')) do
    find("#update_custom_table").trigger('click')
  end
  wait_all_requests

  expect(page).to have_text('Change Role Information')
  within ('[name="custom_table_field_edit_ctrl.form"]') do
    find('[placeholder="Location"]').trigger('click')
    expect(page).not_to have_text('Kashmir')
    find('.md-primary').trigger('click')
  end
  wait_all_requests

  within find(".white-bg", text: ('Role Information')) do
    find("#update_custom_table").trigger('click')
  end
  wait_all_requests

  expect(page).to have_text('Change Role Information')
  within ('[name="custom_table_field_edit_ctrl.form"]') do
    find('[placeholder="Department"]').trigger('click')
    expect(page).not_to have_text('Data Science')
  end
end

def verify_department_and_location_toggle_for_inactive_user
  navigate_to "/#/role/"+addys.id.to_s
  wait_all_requests
  expect(page).to have_text('Role Information')

  within find(".white-bg", text: ('Role Information')) do
    find("#update_custom_table").trigger('click')
  end
  wait_all_requests

  expect(page).to have_text('Change Role Information')
  within ('[name="custom_table_field_edit_ctrl.form"]') do
    find('[placeholder="Location"]').trigger('click')
    expect(page).not_to have_text('Kashmir')
    find('.md-primary').trigger('click')
  end
  wait_all_requests

  within find(".white-bg", text: ('Role Information')) do
    find("#update_custom_table").trigger('click')
  end
  wait_all_requests

  expect(page).to have_text('Change Role Information')
  within ('[name="custom_table_field_edit_ctrl.form"]') do
    find('[placeholder="Department"]').trigger('click')
    expect(page).not_to have_text('Data Science')
  end
end

def add_new_group_type
  find('#create-group-type').trigger('click')
  wait_all_requests

  expect(page).to have_text('New Group Type')
  fill_in 'name', with: "Departments"
  click_on 'Save'
  expect(page).to have_content('Name is already in use.')

  wait_all_requests
  fill_in 'name', with: "Locations"
  click_on 'Save'
  expect(page).to have_content('Name is already in use.')

  wait_all_requests
  fill_in 'name', with: '"Squad"'
  expect(page).to have_content('Name cannot contain double quotes and tags.')
  wait_all_requests

  fill_in 'name', with: "Squad"
  choose_item_from_dropdown('custom_table','Role Information')
  wait_all_requests
  click_on 'Save'
  wait_all_requests
end

def add_new_group_in_new_type
  click_on 'New Squad'
  wait_all_requests
  

  expect(page).to have_text('New Group')
  within '.edit-owner-dialog-wrapper' do
    expect(page).to have_text('Squad')
  end
  fill_in I18n.t('admin.groups.group_dialog.name'), with: "Prime"
  wait_all_requests

  click_button 'Save'
  wait_all_requests
  expect(page).to have_css('.dataTable td')
  active_members = page.find('.dataTable tr:nth-child(1) td:nth-child(2)').text

  expect(active_members).to eq('0')
  inactive_members = page.find('.dataTable tr:nth-child(1) td:nth-child(3)').text
  expect(inactive_members).to eq('0')
end

def set_active_user_new_group_type
  navigate_to "/#/role/"+nick.id.to_s
  wait_all_requests
  expect(page).to have_text('Role Information')

  within find(".white-bg", text: ('Role Information')) do
    find("#update_custom_table").trigger('click')
  end
  wait_all_requests

  expect(page).to have_text('Change Role Information')
  choose_item_from_dropdown('squad','Prime')
  click_button 'Submit'
  wait_all_requests
end

def set_inactive_user_new_group_type
  navigate_to "/#/role/"+peter.id.to_s
  wait_all_requests
  expect(page).to have_text('Role Information')

  within find(".white-bg", text: ('Role Information')) do
    find("#update_custom_table").trigger('click')
  end
  wait_all_requests

  expect(page).to have_text('Change Role Information')
  choose_item_from_dropdown('squad','Prime')
  fill_in 'job_title', with: 'SE'

  click_button 'Submit'
  wait_all_requests
end

def verify_active_and_inactive_count_of_new_group
  find('button.dashboard-menu-btn').trigger('click')
  wait_all_requests
  click_on 'Squad'
  wait_all_requests

  expect(page).to have_css('.dataTable td')
  expect(page).to have_text('Squad')
  active_members = page.find('.dataTable tr:nth-child(1) td:nth-child(2)').text

  expect(active_members).to eq('1')
  inactive_members = page.find('.dataTable tr:nth-child(1) td:nth-child(3)').text
  expect(inactive_members).to eq('1')
end

def disable_new_group_toggle
  wait_all_requests
  find('.md-bar').trigger('click')
  wait_all_requests

  expect(page).to have_css('.dataTable td')
  expect(page).to have_text('Prime')
end

def verify_new_group_toggle_for_active_user
  navigate_to "/#/role/"+tim.id.to_s
  wait_all_requests
  expect(page).to have_text('Role Information')

  within find(".white-bg", text: ('Role Information')) do
    find("#update_custom_table").trigger('click')
  end
  wait_all_requests

  expect(page).to have_text('Change Role Information')
  within ('[name="custom_table_field_edit_ctrl.form"]') do
    find('[placeholder="Squad"]').trigger('click')
    expect(page).not_to have_text('Prime')
  end
end

def verify_new_group_toggle_for_inactive_user
  navigate_to "/#/role/"+addys.id.to_s
  wait_all_requests
  expect(page).to have_text('Role Information')

  within find(".white-bg", text: ('Role Information')) do
    find("#update_custom_table").trigger('click')
  end
  wait_all_requests

  expect(page).to have_text('Change Role Information')
  within ('[name="custom_table_field_edit_ctrl.form"]') do
    find('[placeholder="Squad"]').trigger('click')
    expect(page).not_to have_text('Prime')
  end

  find('.md-button.md-primary.ng-binding').trigger('click')
  wait_all_requests
end

def edit_new_group_type
  find('button.dashboard-menu-btn').trigger('click')
  wait_all_requests
  click_on 'Squad'
  wait_all_requests

  find('[aria-label="icon-dots-horizontal"]').trigger('click')
  wait_all_requests
  click_button I18n.t('admin.groups.group_dialog.edit_details')
  wait_all_requests

  expect(page).to have_text('Edit Group Type')
  fill_in 'name', with: "squad editing"
  click_on 'Save'
  wait_all_requests

  find('button.dashboard-menu-btn').trigger('click')
  expect(page).to have_text('squad editing')
end

def delete_new_group_type
  wait_all_requests
  click_on 'squad editing'
  wait_all_requests

  find('[aria-label="icon-dots-horizontal"]').trigger('click')
  wait_all_requests
  click_button I18n.t('admin.groups.group_dialog.delete')
  wait_all_requests

  expect(page).to have_text('Are you sure you want to delete this Group Type?')
  click_on 'Yes'
  wait_all_requests
  
  expect(page).to have_text('Departments')
  find('button.dashboard-menu-btn').trigger('click')
  wait_all_requests
  expect(page).not_to have_text('squad editing')
end
