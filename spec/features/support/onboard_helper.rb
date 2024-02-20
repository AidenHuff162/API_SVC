def navigate_to_onboard
  wait_all_requests
  page.find(:css,'.md-locked-open').hover
  wait_all_requests

  click_link('Dashboard')
  wait_all_requests
end

def create_user_profile
  click_link (I18n.t('admin.dashboard.overview.onboard_employee_button_txt'))
  wait(5)

  fill_in :first_name, with: 'Tim'
  expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='additional_info_form']/button/span", text: "Save and continue")

  fill_in :last_name, with: 'Taylor'
  expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='additional_info_form']/button/span", text: "Save and continue")

  fill_in :personal_email, with: Faker::Internet.user_name + '@test.com'
  expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='additional_info_form']/button/span", text: "Save and continue")

  fill_in :email, with: 'muhammad+101@trysapling.com'
  expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='additional_info_form']/button/span", text: "Save and continue")

  choose_item_from_autocomplete('job_title', "Head of Operations")
  expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='additional_info_form']/button/span", text: "Save and continue")

  page.find('#date .md-datepicker-triangle-button').trigger('click')
  wait_all_requests

  page.find('.md-focus').trigger('click')
  wait(1)

  choose_item_from_autocomplete_smart('location', location.name)
  choose_item_from_autocomplete_smart('employee_type','Full Time')
  choose_item_from_autocomplete_smart('team',team.name)
  choose_item_from_autocomplete_smart('manager', "#{sarah.preferred_name} #{sarah.last_name}")

  wait_all_requests
  click_on ('Save and continue')
end

def navigate_to_dashboard
  navigate_to('/#/admin/dashboard/onboarding')
  wait(5)
end

def filter_users_by_stage(selected_stage, stage_name)
  page.find('#stages').click
  wait_all_requests

  page.find('md-checkbox', :text => "#{selected_stage}").click
  wait_all_requests

  page.find('md-checkbox', :text => "#{stage_name}").click
  page.find('.apply-button').click
  wait(3)

  all_users = page.all('table tbody tr').count
  expect(all_users).to eq(1)

  stage_name = page.find('.text-boxed').text
  expect(stage_name).to eq("#{stage_name}")
  wait(3)
end

def filter_users_by_department(selected_department, department_name)
  page.find('#teams').click
  wait_all_requests

  page.find('md-checkbox', :text => "#{selected_department}").click
  wait_all_requests

  page.find('md-checkbox', :text => "#{department_name}").click
  page.find('.apply-button').click
  wait(3)

  all_users = page.all('table tbody tr').count
  expect(all_users).to eq(1)

  department_name = page.find('table tbody td:nth-child(3)').text
  expect(department_name).to eq("#{department_name}")
  wait(3)
end

def filter_users_by_location(selected_location, location_name)
  page.find('#locations').click
  wait_all_requests

  page.find('md-checkbox', :text => "#{selected_location}").click
  wait_all_requests

  page.find('md-checkbox', :text => "#{location_name}").click
  page.find('.apply-button').click
  wait(3)

  all_users = page.all('table tbody tr').count
  expect(all_users).to eq(1)

  location_name = page.find('table tbody td:nth-child(4)').text
  expect(location_name).to eq("#{location_name}")
  wait(3)
end

def verify_users_count_on_dashboard
  all_users = page.all('table tbody tr').count
  expect(all_users).to eq(6)
end

def reset_filters
  page.find('.clear-btn', :text => "Clear").click
  wait(3)
end

def add_user_employee_record
  find(".drop_button").trigger("click")
  wait(3)
  find(".md-button", :text => "US Profile Template").trigger("click")
  wait(3)
  choose_item_from_autocomplete('buddy', "#{sarah.preferred_name} #{sarah.last_name}")
  find('#fill-by-new-hire .icon-chevron-down').click()
  wait_all_requests

  fill_in :social_security_number, with: '789-25-7412'
  fill_in :'food_allergies/preferences', with:'Rice'
  fill_in :'dream_vacation_spot', with:Faker::Address.city

  choose_item_from_dropdown('federal_marital_status','Single')
  wait_all_requests

  fill_in :'about-you', with: 'I am Greate Tester'
  fill_in :favorite_food, with:'Bar BQ'
  page.execute_script("$(\"md-datepicker[name='date_of_birth'] input\").val('05/22/1993').trigger('input')")

  fill_in :linkedin, with: 'linkedin.com'
  fill_in :'pets_and_animals', with:'Dogs'
  # fill_in :'home_address_line_1', with: Faker::Address.street_address
  fill_in :'home_address_line_2', with: Faker::Address.street_name
  fill_in :'home_address_city', with: Faker::Address.city

  choose_item_from_dropdown('home_address_country','United States')
  wait_all_requests

  choose_item_from_dropdown('home_address_state','AL')
  wait_all_requests

  fill_in :'home_address_zip', with: '85214'
  wait_all_requests

  fill_in :twitter, with: 'twitter.com'
  choose_item_from_dropdown('t-shirt_size','Small')
  wait_all_requests

  choose_item_from_dropdown('gender','Male')
  fill_in :preferred_name, with:'Tim'
  fill_in :github, with: 'github.com'
  choose_item_from_dropdown('race/ethnicity','Asian')
  wait_all_requests

  fill_in :'emergency_contact_name', with:'Tester'
  choose_item_from_dropdown('emergency_contact_relationship','Wife')

  fill_in :'emergency_contact_number', with:'7852936'
  fill_in :'home_phone_number', with:'04278601'
  fill_in :'mobile_phone_number', with:'09528524'
  wait_all_requests

  find("#save_employee_record").trigger("click")
end

def assign_activities
#   create_single_sign_document
#   hello_sign_steps_single_document
#   verify_assign_documents

  create_upload_request
  verify_assign_uploads_request

  create_co_sign_document
  hello_sign_steps_co_sign_document
  verify_co_assign_documents

  find("[name=assign_workflow]").trigger('click')
  find("[name=assign_workflow] input").send_keys('workstream1')
  wait_all_requests
  find('md-autocomplete-parent-scope', text: 'workstream1', match: :first).trigger('click')
  wait(5)
  workflow_count = page.find('.workflows_count').text
  task_count = page.find('.task_count').text
  assign_count = page.find('.assign_count').text

  expect(workflow_count).to eq('1')
  expect(task_count).to eq('5')
  expect(assign_count).to eq('2')
  wait(2)
end

def wait_all_requests
  page.evaluate_script('jQuery.active').zero?
  page.evaluate_script('$.active') == 0
  wait(1)
end

def submit_activities
  wait_all_requests
  wait(25)
  find('button#assign-activites-submit').trigger("click")
  wait_all_requests
end

def create_single_sign_document
  wait(3)
  page.find('button', text: 'CREATE NEW DOCUMENT').trigger('click')
  wait_all_requests
  fill_in :'title',  with:'Test Document'
  fill_in :'description',  with:'Please sign it'

  attach_ng_file('document', Rails.root.join('spec/factories/uploads/documents/document.pdf'), controller: 'documents_dialog')
  wait_all_requests
  wait_for_element('[type="submit"]')
  wait_all_requests

  click_on I18n.t('admin.documents.paperwork.prepare')
end

def create_co_sign_document
  wait(3)
  click_on I18n.t('admin.onboard.assign_activities.paperwork.create_new_document')

  fill_in :'title',  with:'Test Co-Assign Document'
  fill_in :'description',  with:'Please sign it'
  choose_item_from_dropdown('representative','Another Team Member Co-Signs')
  wait_all_requests

  choose_item_from_autocomplete("cosign_representative","#{sarah.preferred_name} #{sarah.last_name}")
  attach_ng_file('document', Rails.root.join('spec/factories/uploads/documents/document.pdf'), controller: 'documents_dialog')
  wait_all_requests
  wait_for_element('[type="submit"]')
  wait_all_requests

  click_on I18n.t('admin.documents.paperwork.prepare')
end

def hello_sign_steps_single_document
   wait(10)
  if alert_present? == true
    page.accept_alert
  end
 wait(20)

  wait_for_element('img.doc_page_imgss')
  within_frame(find('#hsEmbeddedFrame')) do
    page.execute_script("$('#form_button_form_signature').click()")
    page.execute_script("$('img.doc_page_img')[0].click()")
    wait(3)
    page.find('#saveButton button').trigger('click')
    wait_all_requests
  end
end

def hello_sign_steps_co_sign_document
   wait(10)
  if alert_present? == true
    page.accept_alert
  end
 wait(20)
  wait_for_element('img.doc_page_imgss')
  within_frame(find('#hsEmbeddedFrame')) do
    page.execute_script("$('#form_button_form_signature').click()")
    page.execute_script("$('img.doc_page_img')[0].click()")
    wait_all_requests

    page.execute_script("$('.wrapper.interactive p').click()")
    wait_all_requests

    page.execute_script("$('.assignment-select').val(2).change()")
    wait_all_requests
    page.execute_script("$('img.doc_page_img')[0].click()")
    page.execute_script("$('img.doc_page_img')[0].click()")
    wait(3)

    page.execute_script("$('.component-interact.pink .assignment-select').val(1).change()")
    wait_all_requests
    page.find('#saveButton button').trigger('click')
    wait_all_requests
  end

end

def verify_co_assign_documents
  doc_name = page.find('.list_documents div:nth-child(4) .assign_documents .document_name').text
  expect(doc_name).to eq('Test Co-Assign Document')
  request_name = page.find('.list_documents div:nth-child(4) .assign_documents #doc_request_name').text
  expect(request_name).to eq('Signature Request')
end

def verify_assign_documents
  assign_doc_name = page.find('.document_name').text
  expect(assign_doc_name).to eq('Test Document')
  wait_all_requests

  request_name = page.find('#doc_request_name').text
  expect(request_name).to eq('Signature Request')
end

def verify_assign_uploads_request
  upload_doc_name = page.find('#upload_request_name').text
  expect(upload_doc_name).to eq('Upload Pic')
  upload_request_name = page.find('#request_name').text
  expect(upload_request_name).to eq('Upload Request')
end

def create_upload_request
  click_on I18n.t('admin.onboard.assign_activities.paperwork.upload_requested')
  wait_for_element('titles')

  fill_in :'title', with:'Upload Pic'
  fill_in :'description', with:'Upload Your Pic Please'

  page.find('.assign-doc .sapling-primary').trigger('click')
end

def pending_hire_assign_activities
  wait_all_requests
  page.find('#assign-activites-submit').trigger('click')
end

def send_manager_buddy_emails
  wait(10)
  emails = ActionMailer::Base.deliveries.select { |email| email.subject == "Welcome Tim\u200C" || email.subject == "You've been assigned to\u{a0}Tim Taylor\u{200c}." || email.subject == "You've been assigned to\u{a0}Tim Taylor\u{200c}."}
  expect(emails.count).to eq(3)
end

def send_manager_buddy_welcome_email
  wait(5)
  total_emails_trigger =  ActionMailer::Base.deliveries
  emails = ActionMailer::Base.deliveries.select { |email| email.subject == "Welcome Tim\u200C" || email.subject == "You've been assigned to\u{a0}Tim Taylor\u{200c}." || email.subject == "You've been assigned to\u{a0}Tim Taylor\u{200c}."}
  expect(emails.count).to eq(3)
  expect(User.last.user_emails.last.subject).to eq("<p>Welcome email for Tim\u{200c}Taylor\u{200c}</p>")
  expect(User.last.user_emails.last.email_status).to eq(0)
end

def pending_onboarding
  wait_all_requests
  click_link I18n.t('admin.header.nav.home')
  wait_for_element('.md-confirm-button')

  page.find('.md-confirm-button').click
  wait(2)
end

def onboard_pending_hires
  wait_all_requests
  page.find('#pending-hire-button').trigger('click')
  wait_all_requests

  wait_for_element('.pending-hire-action-menu')
  page.first('.sapling-flat').trigger('click')
  wait_for_element('[name="about-you"]')
  expect(page).to have_content I18n.t('admin.onboard.employee_record.profile_information_subheading')
end

def create_user_profile_with_namely
  click_link (I18n.t('admin.dashboard.overview.onboard_employee_button_txt'))

  fill_in :first_name, with: 'Tim'
  fill_in :last_name, with: 'Taylor'
  fill_in :personal_email, with: Faker::Internet.user_name + '@test.com'
  fill_in :email, with: Faker::Internet.user_name + '@foo.com'

  fill_in :job_tier, with: 'ConsultantsA'
  wait(10)

  choose_item_from_autocomplete('job_title', 'Head of Operations')
  page.execute_script('$("#date .md-datepicker-button").click()')
  wait_all_requests()

  page.execute_script('$(".md-calendar [md-calendar-month-body]:nth-child(4) .md-focus").click()')
  wait(1)

  choose_item_from_autocomplete_smart('location', location.name)
  choose_item_from_autocomplete_smart('employee_type','Full Time')
  choose_item_from_autocomplete_smart('team',team.name)
  choose_item_from_autocomplete_smart('manager', "#{sarah.preferred_name} #{sarah.last_name}")

  click_on ('Save and continue')
end

def add_user_employee_record_for_namely
  find(".drop_button").trigger("click")
  wait(3)
  find(".md-button", :text => "US Profile Template").trigger("click")
  wait(3)
  choose_item_from_autocomplete('buddy', "#{sarah.preferred_name} #{sarah.last_name}")
  find('#fill-by-new-hire .icon-chevron-down').click()
  wait_all_requests

  fill_in :social_security_number, with: '789-25-7412'
  fill_in :'food_allergies/preferences', with:'Rice'
  fill_in :'dream_vacation_spot', with:Faker::Address.city

  choose_item_from_dropdown('federal_marital_status','Single')
  wait_all_requests

  fill_in :'about-you', with: 'I am Greate Tester'
  fill_in :favorite_food, with:'Bar BQ'
  page.execute_script("$(\"md-datepicker[name='date_of_birth'] input\").val('05/22/1993').trigger('input')")


  fill_in :linkedin, with: 'linkedin.com'
  fill_in :'pets_and_animals', with:'Dogs'
  # fill_in :'home_address_line_1', with: Faker::Address.street_address
  fill_in :'home_address_line_2', with: Faker::Address.street_name
  fill_in :'home_address_city', with: Faker::Address.city

  choose_item_from_dropdown('home_address_state','AL')
  wait_all_requests

  fill_in :'home_address_zip',    with: '85214'
  wait_all_requests

  choose_item_from_dropdown('home_address_country','United States')
  fill_in :twitter, with: 'twitter.com'
  choose_item_from_dropdown('t-shirt_size','Small')
  wait_all_requests

  choose_item_from_dropdown('gender','Male')
  fill_in :preferred_name, with:'Tim'
  fill_in :github, with: 'github.com'
  choose_item_from_dropdown('race/ethnicity','Asian')
  wait_all_requests

  fill_in :'emergency_contact_name', with:'Tester'
  choose_item_from_dropdown('emergency_contact_relationship','Wife')

  fill_in :'emergency_contact_number', with:'7852936'
  fill_in :'home_phone_number', with:'04278601'
  fill_in :'mobile_phone_number', with:'09528524'

  click_on ('Save and continue')
end

def delete_users
  wait(2)
  users_count = page.all('.dataTable tr .icon-dots-horizontal').length
  (1..users_count).each do
    wait_all_requests
    page.find(".dataTable tr:nth-child(1) .icon-dots-horizontal").trigger('click')
    wait_all_requests

    page.find(".md-active md-menu-item:nth-child(4) button").click
    wait_all_requests

    click_button('Yes')
    wait(2)
    wait_all_requests

    expect(page).to have_selector('.md-toast-content .md-toast-text', text: 'User Deleted')
  end

  wait_all_requests
  users_count = page.all('.dataTable tr .icon-dots-horizontal').length
  expect(users_count).to eq(0)
end

def initiate_onboarding
  find('span.initiate-schedule-emails', text: 'INITIATE ONBOARDING', visible: :all).click
  wait(5)
  text = 'Tim has been added to your Onboarding Dashboard'
  expect(find('span.align-top-verticle', text: text, visible: :all).text).to eq(text)
end

def create_schedule_email
  wait_all_requests
  wait(5)
  page.find('span.ng-binding', text: 'Add SCHEDULED EMAIL', visible: :all).click
  wait_all_requests
  wait(10)
  page.execute_script("$('#email-description .ql-editor').html('You may join us at apointed schedule');")
  page.execute_script("$('#email-subject .ql-editor').html('Welcome Here');")
  wait_all_requests
  wait(10)
  find('span.ng-binding', text: 'Send', visible: :all).click
end
