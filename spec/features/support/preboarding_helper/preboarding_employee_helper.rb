def navigate_to_employee_record
  navigate_to '/#/admin/company/profile_setup'
  wait(2)
  wait_all_requests
end

def navigate_to_preboarding
  navigate_to '/#/welcome'
  wait(2)
end

def uncheck_require_fields
  uncheck_require_profile_fields(1)
  uncheck_require_profile_fields(2)
  uncheck_require_profile_fields(3)
  uncheck_require_profile_fields(4)
end

def uncheck_require_profile_fields(section)
  wait(5)
  profile_fields_count = page.all("#section:nth-child(#{section}) .profile_information_fields #list_item md-checkbox").count
  profile_fields = page.all("#section:nth-child(#{section}) .profile_information_fields #list_item md-checkbox")
  $i = 0
  while $i < profile_fields_count do
    profile_fields[$i].click
    wait(2)
    $i +=1
  end
  wait_all_requests
end

def verify_welcome_page
    expect(page).to have_text I18n.t('preboard.welcome', company: company.name)
    expect(page).to have_text I18n.t('notifications.admin.company.welcome_note')
    click_button "BEGIN PREBOARDING"
    wait_all_requests
end

def verify_our_story_page
  expect(page).to have_text I18n.t('preboard.our_story.title', company: company.name)
  click_button I18n.t('preboard.next')
  wait_all_requests
end

def verify_your_team_page
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.people.team_members.title')
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.people.onboarding_class')
    click_button I18n.t('preboard.next')
    wait_all_requests
end

def verify_complete_your_profile_page
  expect(page).to have_text I18n.t('preboard.about_you.profile_photo')
  clear_public_profile_fields
  clear_personal_info_fields
  clear_additional_info_fields
  clear_private_info_fields

  click_button('Submit')
  wait_all_requests
end

def verify_congratulations_dialog
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.congrats.all_done')
    click_on I18n.t('preboard.congrats.continue')
    wait_all_requests
    expect(page).to have_text I18n.t('onboard.home.profile.profile')
  end

def clear_personal_info_fields
  wait(3)
  wait_all_requests
  fill_in :preferred_name, with: ""
  fill_in :home_phone_number, with: ""
  fill_in :mobile_phone_number, with: ""
end

def clear_public_profile_fields
  fill_in :about_you, with: "a"
  fill_in :linkedin, with: "b"
  fill_in :twitter, with: "c"
  fill_in :github, with: "d"

  click_on I18n.t('preboard.next')
  wait(1)
  wait_all_requests
end

def clear_additional_info_fields
  fill_in :'food_allergies/preferences', with: ""
  fill_in :dream_vacation_spot, with: ""
  fill_in :favorite_food, with: ""
  fill_in :pets_and_animals, with: ""
  choose_item_from_dropdown("t-shirt_size", "")
end

def clear_private_info_fields
  find('[name="social_security_number"]').set("")
  choose_item_from_dropdown('federal_marital_status','')
  wait_all_requests
  fill_in :home_address_line_1, with: ""
  fill_in :home_address_line_2, with: ""
  fill_in :home_address_city, with: ""
  wait_all_requests
  fill_in :'home_address_zip', with: ""
  choose_item_from_dropdown("gender", "")
  choose_item_from_dropdown('race/ethnicity','Asian')
  fill_in :emergency_contact_name, with: "Test Name"
  choose_item_from_dropdown('emergency_contact_relationship','')
  wait(2)
  fill_in :emergency_contact_number, with: "030078601"
end
