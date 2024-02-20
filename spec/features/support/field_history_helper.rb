def personal_field_validation
    wait_all_requests
    fill_in :first_name, with: user_attributes[:first_name]
    wait(1)
    fill_in :last_name, with: user_attributes[:last_name]
    wait(1)
    fill_in :company_email, with: user_attributes[:email]
    wait(1)
    fill_in :personal_email, with: user_attributes[:personal_email]
    wait(1)
    fill_in :preferred_name, with: user_attributes[:preferred_name]
    wait(1)
    find('.start_date .md-datepicker-button').trigger('click')
    wait(1)
    page.execute_script('$(".md-calendar [md-calendar-month-body]:nth-child(4) .md-focus").click()')
    wait(1)
    choose_item_from_autocomplete('buddy', "#{user.first_name} #{user.last_name}")
    wait(1)
    choose_item_from_dropdown('access_permission','Super Admin')
    wait(1)
    fill_in :home_phone_number,     with: '03009876543'
    wait(1)
    fill_in :mobile_phone_number,   with: '03001234567'
    wait(1)
    page.execute_script("$[button:contains('Save'):enabled].click()")
    wait(1)
end

def additional_field_validation
  wait_all_requests
  fill_in :'food_allergies/preferences',  with:'Rice'
  wait(1)
  fill_in :'dream_vacation_spot',  with: 'London'
  wait(1)
  fill_in :'favorite_food',  with:'Pizza'
  wait(1)
  fill_in :'pets_and_animals',  with:'Dogs'
  wait(1)
  choose_item_from_dropdown('t-shirt_size','X-Large')
  wait(1)
  page.execute_script("$[button:contains('Save'):enabled].click()")
  wait(1)
end

def private_field_validation
  wait_all_requests
  find('[name="social_security_number"]').set("323333333")
  wait(1)
  choose_item_from_dropdown('federal_marital_status','Single')
  wait(1)
  add_to_date_picker('date_of_birth','05-22-1993')
  wait(1)
  fill_in :'home_address_line_1', with: 'Headquarters 1120 N'
  wait(1)
  fill_in :'home_address_line_2', with: 'Street Sacramento'
  wait(1)
  fill_in :'home_address_city',    with: 'Caltrans'
  wait(1)
  choose_item_from_dropdown('home_address_state','AL')
  wait(1)
  fill_in :'home_address_zip',  with: '32335'
  wait(1)
  choose_item_from_dropdown('gender','Male')
  wait(1)
  choose_item_from_dropdown('race/ethnicity','Asian')
  wait(1)
  fill_in :emergency_contact_name, with: user_attributes[:first_name]
  wait(1)
  choose_item_from_dropdown('emergency_contact_relationship','Father')
  wait(1)
  fill_in :emergency_contact_number, with:'03001234567'
  wait(1)
  page.execute_script("$[button:contains('Save'):enabled].click()")
  wait(1)
end

def navigate_to_employee_record_for_user
  wait_all_requests
  navigate_to '/#/profile'
  wait_all_requests
  wait(2)
  page.all('.section-right-approval-icons .icon-pencil').each do |el|
    el.trigger('click')
  end
  wait_all_requests
end

def personal_history_data
  wait(1)
  page.execute_script("$('.md-container').click()")
  wait_all_requests
  history_array = find_all('.icon-clock')
  field_array = find_all('.md-input')
  drop_down_array = find_all('.md-select-value')
  history_field_data(history_array,0,"Sabrina",field_array,0)
  history_field_data(history_array,1,"parker",field_array,1)
  history_field_data(history_array,2,"Sab",field_array,2)
  history_field_data(history_array,3,"sabrina.company@gmail.com",field_array,3)
  history_field_data(history_array,4,"sabrina.personal@gmail.com",field_array,4)
  history_field_data(history_array,7,"0123456",field_array,5)
  history_field_data(history_array,9,"456498",field_array,6)
  wait_all_requests
  page.execute_script("$[button:contains('Save'):enabled].click()")
  wait_all_requests
end

def additional_history_data
  wait_all_requests
  history_array = find_all('.icon-clock')
  field_array = find_all('.md-input')
  drop_down_array = find_all('.md-select-value')
  history_field_data(history_array,0,"Sabrina",field_array,0)
  history_field_data(history_array,1,"parker",field_array,1)
  history_field_data(history_array,2,"Sab",field_array,2)
  history_field_data(history_array,3,"sabrina.company@gmail.com",field_array,3)
  history_dropdowns(history_array,4,'size',drop_down_array,0)
  wait_all_requests
  page.execute_script("$[button:contains('Save'):enabled].click()")
  wait_all_requests
end

def private_history_data
  wait_all_requests
  history_array = find_all('.icon-clock')
  field_array = find_all('.md-input')
  drop_down_array = find_all('.md-select-value')
  ssn_field_validation(history_array,0)
  history_field_data(history_array,5,"Black",field_array,6)
  history_field_data(history_array,6,"jaylin",field_array,7)
  history_field_data(history_array,8,"090078601",field_array,8)
  input_dropdowns(history_array,1,'Married',drop_down_array,0)
  input_dropdowns(history_array,4,'Female',drop_down_array,3)
  input_dropdowns(history_array,7,'Wife',drop_down_array,4)
  page.execute_script("$[button:contains('Save'):enabled].click()")
end

def input_dropdowns(array,array_index,input,dropdown_data,dropdown_index)
  dropdown_field_data = dropdown_data[dropdown_index].text
  username = find('.login_username').text
  array[array_index].trigger("click")
  wait_all_requests
  history_username = find_all('[name="history_username"]')
  expect(page).to have_selector('.sapling-header', :text => I18n.t('admin.field_history.dialog_title'))
  text = find_all('[ng-if="!audit_log.isEditable"]')
  if(dropdown_field_data == text[0].text && username == history_username[0])
    edit_icon = find_all('.icon-pencil')
    edit_icon[0].trigger("click")
    expect(page).to have_selector('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase)
    if(input == 'Large')
      choose_item_from_dropdown('history_drop_down', 'Large')
      wait_all_requests
      find('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase).trigger("click")
    elsif(input == 'Female')
      choose_item_from_dropdown('history_drop_down', 'Female')
      wait_all_requests
      find('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase).trigger("click")
    elsif(input == 'Wife')
      choose_item_from_dropdown('history_drop_down', 'Wife')
      wait_all_requests
      find('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase).trigger("click")
    elsif(input == 'Married')
      choose_item_from_dropdown('history_drop_down', 'Married')
      wait_all_requests
      find('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase).trigger("click")
    elsif(input == 'employement_status')
      choose_item_from_dropdown('history_drop_down', 'Part Time')
      wait_all_requests
      find('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase).trigger("click")
    end

    if(text[0] == input)
      find(".icon-trash").trigger("click")
      expect(page).to have_selector('.secondary-text', :text => I18n.t('admin.field_history.confirmation'))
      expect(page).to have_selector('.table-clickable', :text => I18n.t('admin.field_history.confirmation_deletion'))
      find('.table-clickable', :text => I18n.t('admin.field_history.confirmation_deletion')).trigger("click")
      expect(page).to have_selector('[role="alert"]', :text => I18n.t('admin.field_history.event_deleted'))
     end
   end
  find('#history_close').trigger("click")
  wait_all_requests
end

def history_field_data(array,array_index,input,field_data,field_index)
  field_value = field_data[field_index].value
  username = find('.login_username').text
  array[array_index].trigger("click")
  wait_all_requests
  history_username = find_all('[name="history_username"]')
  expect(page).to have_selector('.sapling-header', :text => I18n.t('admin.field_history.dialog_title'))
  text = find_all('[ng-if="!audit_log.isEditable"]')
  edit_icon = find_all('.icon-pencil')
  if (field_value == text[0].text && username == history_username[0])
    edit_icon[0].trigger("click")
    expect(page).to have_selector('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase)
    fill_in :'history_input', with: input
    find('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase).trigger("click")
    if(text[0] == input)
      find(".icon-trash").trigger("click")
      expect(page).to have_selector('.secondary-text', :text => I18n.t('admin.field_history.confirmation'))
      expect(page).to have_selector('.table-clickable', :text => I18n.t('admin.field_history.confirmation_deletion'))
      find('.table-clickable', :text => I18n.t('admin.field_history.confirmation_deletion')).trigger("click")
      expect(page).to have_selector('[role="alert"]', :text => I18n.t('admin.field_history.event_deleted'))
    end
  end
  find('#history_close').trigger("click")
end

def history_dropdowns(array,array_index,input,dropdown_array,dropdown_index)
  dropdown_data = dropdown_array[dropdown_index].text
  username = find('.login_username').text
  wait_all_requests
  array[array_index].trigger("click")
  wait_all_requests
  history_username = find_all('[name="history_username"]')
  expect(page).to have_selector('.sapling-header', :text => I18n.t('admin.field_history.dialog_title'))
  text = find_all('[ng-if="!audit_log.isEditable"]')
  if (dropdown_data == text[0].text && username == history_username[0])
    edit_icon = find_all('.icon-pencil')
    edit_icon[0].trigger("click")
    expect(page).to have_selector('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase)
    wait_all_requests
    if(input == 'size')
      choose_item_from_dropdown('history_drop_down', 'Large')
      find('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase).trigger("click")
        if(text[0] == input)
          find(".icon-trash").trigger("click")
          expect(page).to have_selector('.secondary-text', :text => I18n.t('admin.field_history.confirmation'))
          expect(page).to have_selector('.table-clickable', :text => I18n.t('admin.field_history.confirmation_deletion'))
          find('.table-clickable', :text => I18n.t('admin.field_history.confirmation_deletion')).trigger("click")
          expect(page).to have_selector('[role="alert"]', :text => I18n.t('admin.field_history.event_deleted'))
        end
    else
      choose_item_from_dropdown('history_drop_down',input.name)
      find('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase).trigger("click")
      text = find_all('[ng-if="!audit_log.isEditable"]')
        if(text[0] == input.name)
          find(".icon-trash").trigger("click")
          expect(page).to have_selector('.secondary-text', :text => I18n.t('admin.field_history.confirmation'))
          expect(page).to have_selector('.table-clickable', :text => I18n.t('admin.field_history.confirmation_deletion'))
          find('.table-clickable', :text => I18n.t('admin.field_history.confirmation_deletion')).trigger("click")
          expect(page).to have_selector('[role="alert"]', :text => I18n.t('admin.field_history.event_deleted'))
        end
    end
  end
  find('#history_close').trigger("click")
end
def ssn_field_validation(array,a_index)
  field_input = find('[name="social_security_number"]').value
  username = find('.login_username').text
  array[a_index].trigger("click")
  expect(page).to have_selector('.sapling-header', :text => I18n.t('admin.field_history.dialog_title'))
  history_username = find_all('[name="history_username"]')
  find('.icon-pencil').trigger("click")
  expect(page).to have_selector('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase)
  history_input = find('[name="history_input"]').value
  if(field_input == history_input && username == history_username[0])
      find('[name="history_input"]').set("123456789")
      find('.md-button', :text => I18n.t("admin.field_history.save_changes").upcase).trigger("click")
      expect(page).to have_selector('.icon-pencil')
      find(".icon-trash").trigger("click")
      expect(page).to have_selector('.secondary-text', :text => I18n.t('admin.field_history.confirmation'))
      expect(page).to have_selector('.table-clickable', :text => I18n.t('admin.field_history.confirmation_deletion'))
      find('.table-clickable', :text => I18n.t('admin.field_history.confirmation_deletion')).trigger("click")
      expect(page).to have_selector('[role="alert"]', :text => I18n.t('admin.field_history.event_deleted'))
  end
  find('#history_close').trigger("click")
end
