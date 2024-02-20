def navigate_to_dashbaord
  navigate_to '/#/admin/dashboard/onboarding'
  wait_all_requests
end

def dashboard_login
  fill_in :email, with: hilda.email
  fill_in :password, with: password
  click_on t('log_in.submit')
  wait_all_requests
  navigate_to_dashbaord
  page.find(:css, '#dashboard_tabs')
end

def verify_side_action
  wait_all_requests
  find('[aria-label="All Stages"]').click
  wait_all_requests
  wait(1)
  person_data_array = get_member_information_first(true)
  click_link I18n.t('admin.dashboard.overview.edit_user.go_to_employee_record').upcase
  wait_all_requests
  wait(1)
  expect(page).to have_selector('.md-active', text: "#{I18n.t('onboard.home.toolbar.profile')}")
  navigate_to '/#/admin/dashboard/onboarding'
end

def traverse_pages(array_to_match, text_element)
  rows = page.all('tbody tr')
  column = ""
  rows.each do |raw|
    if raw.text.include? array_to_match[0]
      within raw do
        column = page.all('td')
      end

      if text_element == "Profile"
        column[0].click
        wait_all_requests
        wait(1)
        click_link I18n.t('board.road_map.employee.view_profile')
        wait_all_requests
        wait(1)
        expect(page).to have_selector('.md-active', text: "#{I18n.t('admin.header.menu.profile')}")

      elsif text_element == "Documents"
        column[5].click
        wait_all_requests
        wait(1)
        expect(page).to have_selector('.md-active', text: "#{I18n.t('board.activities.headings.documents')}")

      elsif text_element == "Tasks"
        column[6].click
        wait_all_requests
        wait(1)
        expect(page).to have_selector('.md-active', text: "#{I18n.t('board.activities.headings.tasks')}")

      end

    end

  end

end

def verify_data_after_update
  wait_all_requests
  find('[aria-label="All Stages"]').click
  wait(1)
  person_data_array = get_member_information_first(true)
  wait_for_element('.md-datepicker-calendar-icon')
  date = (Date.today + 2.days).strftime("%m/%d/%Y")
  page.execute_script("$('.md-datepicker-input').val('#{date}').trigger('input')")
  wait(2)
  click_button('Yes, Update Dates')

  person_data_array[2] = team.name
  person_data_array[1] = (Date.today + 2.days).strftime("%b %-1d")

  find('.md-sidenav-backdrop').click
  wait_all_requests
  find('[aria-label="All Stages"]').click
  wait(1)
  new_person_data_array = Array.new
  rows = page.all('tbody tr')
  rows.each do |raw|
    if raw.text.include? person_data_array[0]
      within raw do
        column = page.all('td')
        new_person_data_array.push(column[0].text)
        new_person_data_array.push(column[1].text)
        new_person_data_array.push(column[2].text)
        wait_all_requests
      end

    end

  end

  expect(new_person_data_array[1]).to eq(person_data_array[1])
  expect(new_person_data_array[2]).to eq(person_data_array[2])
end

def get_member_information_first(click_on_sidebar)
  data = page.all('tbody tr')
  member_information_array = Array.new
  within data[0] do
    column = page.all('td')
    member_information_array.push(column[0].text)
    member_information_array.push(column[1].text)
    member_information_array.push(column[2].text)
    wait_all_requests
    if click_on_sidebar == true
      column[0].click
    end

    wait_all_requests
  end

  return member_information_array
end

def sorts_hires_by_column_type(column_type)
  wait_all_requests
  find('[aria-label="All Stages"]').click
  if column_type == 'by_department'
    department_array = visiting_table('tbody tr', 2)
    page.execute_script("$('thead tr th:nth-child(3)').click()")
    new_department_array = visiting_table('tbody tr', 2)
    department_array = department_array.sort
    expect(department_array).to eq(new_department_array)
  end

end

def verify_filters(element_name, table_id, text_to_find)
  wait_all_requests
  scroll_to(page.find("#dashboard_tabs"))
  find(element_name).click
  wait(1)
  rows = page.all(table_id)
  if !page.has_content?('No data available in table', wait: 0.5)
    rows.each do |raw|
      stage_text = ''
      within raw do
        wait(2)
        column = page.all('td')
        stage_text = column[4].text
        expect(stage_text).to eq(text_to_find)
      end

      wait_all_requests
    end

  end

end

def visiting_table(table_id, id_number)
  wait_all_requests
  scroll_to(page.find("#dashboard_tabs"))
  rows = page.all(table_id)
  if !page.has_content?('No data available in table', wait: 0.5)
    dataArray = Array.new
    rows.each do |raw|
      data = ''
      within raw do
        column = page.all('td')
        data = column[id_number].text
      end

      dataArray.push(data)
    end
    return dataArray
  end

end
