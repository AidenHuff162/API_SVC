def navigate_to_profile_fields
  wait_all_requests
  navigate_to "/#/admin/company/profile_setup"
end

def navigate_to_onboarding_employee_record
  navigate_to "/#/admin/onboard"
  find('md-tab-item').should be_visible
  page.find('md-tab-item', text: I18n.t('admin.onboard.tabs.employee_record')).click
end

def verify_profile_fields_name_functionality
  find('#section:nth-child(1)').should be_visible
  wait(3)

  total_fields = page.all('#section:nth-child(1) .profile_information_fields #list_item').count
  expect(total_fields).to eq(4)
  click_on ('New Field')

  wait_all_requests
  choose_item_from_dropdown('associated_section', 'Profile Information')
  fill_in "field_name", with: ' "Test Profile field" '
  warning_mesg = page.find('.md-input-messages-animation').text
  expect(warning_mesg).to eq("Can't be blank. Double quotes and tags are not accepted.")
  page.find('.icon-close').click

  wait_all_requests
  click_on ('Yes')
  wait_all_requests
end

def custom_fields_for_admin(associated_section, collect_from, field_position, total_fields_count)
  profile_custom_fields(associated_section, collect_from, field_position)
  verify_total_created_fields_count(associated_section, total_fields_count)
end

def custom_fields_for_new_hire(associated_section, collect_from, field_position, total_fields_count)
  profile_custom_fields(associated_section, collect_from, field_position)
  verify_total_created_fields_count(associated_section, total_fields_count)
end

def custom_fields_for_manager(associated_section, collect_from, field_position, total_fields_count)
  profile_custom_fields(associated_section, collect_from, field_position)
  verify_total_created_fields_count(associated_section, total_fields_count)
end

def create_require_custom_field(collect_from)
  find('.all-fields').should be_visible
  wait(3)
  click_button('+ New Field', match: :first)

  wait_all_requests
  # choose_item_from_dropdown('associated_section', 'Profile Information')
  fill_in "field_name", with: 'GitHub'
  warning_mesg = page.find('.md-input-messages-animation').text
  expect(warning_mesg).to eq("This information is required.")

  fill_in "field_name", with: 'Require Field'
  choose_item_from_dropdown('field_type', 'Short Text')
  choose_item_from_dropdown('collect_from', collect_from)
  wait_all_requests
  click_on ('Create')

  expect(page).to have_selector('.md-toast-content .md-toast-text', text: 'Profile Field created')
  wait_all_requests
  find('.all-fields').should be_visible
end

def verify_default_custom_fields
  wait(3)
  page.find('.field-row .icon-lock', match: :first)
  page.find('.field-row', match: :first).click
  wait_all_requests

  disable = page.find('.sapling-primary')[:disabled]
  expect(disable).to eq(true)
end

def edit_custom_fields
  page.find('.field-row', text: "Favorite Food").click
  fill_in "field_name", with: 'Test Require Field'
  choose_item_from_dropdown('field_type', 'Long Text')
  choose_item_from_dropdown('collect_from', 'New Hire')
  wait_all_requests
  click_on ('Update')

  expect(page).to have_selector('.md-toast-content .md-toast-text', text: 'Profile Field updated')
  wait_all_requests
  find('.all-fields').should be_visible

  expect(page).to have_selector(".field-row .sapling-body-2", text: 'Test Require Field')
  expect(page).to have_selector(".field-row .sapling-body-2", text: 'Long Text')
  expect(page).to have_selector("md-chip", text:  'New Hire')
end

def delete_custom_fields
  page.find('.field-row', text: "Require Field", match: :first).find('.md-menu').click
  page.find('.md-button', text: "Delete").click
  wait_all_requests
  click_on('Yes, Delete')
  expect(page).to have_selector('.md-toast-content .md-toast-text', text: 'Profile Field deleted')
  wait_all_requests
  find('.all-fields').should be_visible
  # total_fields = page.all('#section:nth-child(1) .profile_information_fields #list_item').count
  total_fields = page.find('.profile-setup-section', match: :first).all('.field-row').count
  expect(total_fields).to eq(4)
end

private

def profile_custom_fields(associated_section, collect_from, field_position)
  create_custom_profile_fields(associated_section, 'Short Text', 'Short Text', collect_from)
  verify_custom_profile_fields(associated_section, field_position, 'Short Text', 'Short Text', collect_from)

  create_custom_profile_fields(associated_section, 'Long Text', 'Long Text', collect_from)
  verify_custom_profile_fields(associated_section, field_position+1, 'Long Text', 'Long Text', collect_from)

  create_custom_profile_fields(associated_section, 'Address', 'Address', collect_from)
  verify_custom_profile_fields(associated_section, field_position+2, 'Address', 'Address', collect_from)

  create_custom_profile_fields(associated_section, 'Currency', 'Currency', collect_from)
  verify_custom_profile_fields(associated_section, field_position+3, 'Currency', 'Currency', collect_from)

  create_custom_profile_fields(associated_section, 'Confirmation', 'Confirmation', collect_from)
  verify_custom_profile_fields(associated_section, field_position+4, 'Confirmation', 'Confirmation', collect_from)

  create_custom_profile_fields(associated_section, 'Coworker', 'Coworker', collect_from)
  verify_custom_profile_fields(associated_section, field_position+5, 'Coworker', 'Coworker', collect_from)

  create_custom_profile_fields(associated_section, 'Date', 'Date', collect_from)
  verify_custom_profile_fields(associated_section, field_position+6, 'Date', 'Date', collect_from)

  create_custom_profile_fields(associated_section, 'Number', 'Number', collect_from)
  verify_custom_profile_fields(associated_section, field_position+7, 'Number', 'Number', collect_from)

  create_custom_profile_fields(associated_section, 'Phone Number', 'Phone Number', collect_from)
  verify_custom_profile_fields(associated_section, field_position+8, 'Phone Number', 'Phone Number', collect_from)

  create_custom_profile_fields(associated_section, 'SSN', 'Social Security Number', collect_from)
  verify_custom_profile_fields(associated_section, field_position+9, 'SSN', 'Social Security Number', collect_from)

  create_custom_profile_fields(associated_section, 'International Phone', 'International Phone', collect_from)
  verify_custom_profile_fields(associated_section, field_position+10, 'International Phone', 'International Phone', collect_from)

  create_custom_profile_fields(associated_section, 'Multi Select', 'Multi Select', collect_from)
  verify_custom_profile_fields(associated_section, field_position+11, 'Multi Select', 'Multi Select', collect_from)

  create_custom_profile_fields(associated_section, 'Multiple Choice Question', 'Multiple Choice Question', collect_from)
  verify_custom_profile_fields(associated_section, field_position+12, 'Multiple Choice Question', 'Multiple Choice', collect_from)
end

def create_custom_profile_fields(associated_section, field_name, field_type, collect_from)
  click_on ('New Field')
  wait_all_requests

  choose_item_from_dropdown('associated_section', associated_section)
  fill_in "field_name", with: field_name
  wait_all_requests
  choose_item_from_dropdown('field_type', field_type)

  if field_type == 'Multi Select' || field_type == 'Multiple Choice Question'
    page.find('.checkbox-field md-input-container input').send_keys('Option 1')
  end

  choose_item_from_dropdown('collect_from', collect_from)
  wait_all_requests
  click_on ('Submit')

  expect(page).to have_selector('.md-toast-content .md-toast-text', text: 'Profile Field created')
  wait_all_requests
  find('#section:nth-child(1)').should be_visible
end

def verify_custom_profile_fields(associated_section, field_position, field_name, field_type, collect_from)
  if associated_section == 'Profile Information'
    total_fields = page.all('#section:nth-child(1) .profile_information_fields #list_item').count.to_i
    expect(total_fields).to eq(field_position)

    expect(page).to have_selector("#section:nth-child(1) .profile_information_fields #list_item:nth-child(#{field_position}) #list_text span", text: field_name)
    expect(page).to have_selector("#section:nth-child(1) .profile_information_fields #list_item:nth-child(#{field_position}) #field_type", text: field_type)
    expect(page).to have_selector("#section:nth-child(1) .profile_information_fields #list_item:nth-child(#{field_position}) md-chip", text: collect_from )

  elsif associated_section == 'Personal Information'
    total_fields = page.all('#section:nth-child(2) .profile_information_fields #list_item').count.to_i
    expect(total_fields).to eq(field_position)

    expect(page).to have_selector("#section:nth-child(2) .profile_information_fields #list_item:nth-child(#{field_position}) #list_text span", text: field_name)
    expect(page).to have_selector("#section:nth-child(2) .profile_information_fields #list_item:nth-child(#{field_position}) #field_type", text: field_type)
    expect(page).to have_selector("#section:nth-child(2) .profile_information_fields #list_item:nth-child(#{field_position}) md-chip", text: collect_from )

  elsif associated_section == 'Additional Information'
    total_fields = page.all('#section:nth-child(3) .profile_information_fields #list_item').count.to_i
    expect(total_fields).to eq(field_position)

    expect(page).to have_selector("#section:nth-child(3) .profile_information_fields #list_item:nth-child(#{field_position}) #list_text span", text: field_name)
    expect(page).to have_selector("#section:nth-child(3) .profile_information_fields #list_item:nth-child(#{field_position}) #field_type", text: field_type)
    expect(page).to have_selector("#section:nth-child(3) .profile_information_fields #list_item:nth-child(#{field_position}) md-chip", text: collect_from )

  else
    total_fields = page.all('#section:nth-child(4) .profile_information_fields #list_item').count.to_i
    expect(total_fields).to eq(field_position)

    expect(page).to have_selector("#section:nth-child(4) .profile_information_fields #list_item:nth-child(#{field_position}) #list_text span", text: field_name)
    expect(page).to have_selector("#section:nth-child(4) .profile_information_fields #list_item:nth-child(#{field_position}) #field_type", text: field_type)
    expect(page).to have_selector("#section:nth-child(4) .profile_information_fields #list_item:nth-child(#{field_position}) md-chip", text: collect_from )
  end
end

def verify_total_created_fields_count(associated_section, associated_section_total_fields)
  if associated_section == 'Profile Information'
    total_fields = page.all("#section:nth-child(1) .profile_information_fields #list_item").count
    expect(total_fields).to eq(associated_section_total_fields)

  elsif associated_section == 'Personal Information'
    total_fields = page.all("#section:nth-child(2) .profile_information_fields #list_item").count
    expect(total_fields).to eq(associated_section_total_fields)

  elsif associated_section == 'Additional Information'
    total_fields = page.all("#section:nth-child(3) .profile_information_fields #list_item").count
    expect(total_fields).to eq(associated_section_total_fields)

  else
    total_fields = page.all("#section:nth-child(4) .profile_information_fields #list_item").count
    expect(total_fields).to eq(associated_section_total_fields)
  end

  def verify_fields_in_onboarding_process(collect_from, total_fields_count, required_fields)
    navigate_to '/#/admin/onboard'
    wait(5)
    page.find('md-tab-item:nth-child(2)').click
    wait_all_requests
    admin_fields_count = page.find("#employee-record-panel #fill-by-#{collect_from} .fields_count").text
    expect(admin_fields_count).to eq("Total Fields: #{total_fields_count} | Required: #{required_fields} | Hidden: 0")
   end
end
