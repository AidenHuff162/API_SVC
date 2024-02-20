  def user_can_complete_landing
    check_user_has_reached_landing
    user_can_set_password_in_landing
  end

  def check_user_has_reached_landing
    expect(page).to have_text I18n.t('preboard.landing.welcome.title', name: nick.first_name)
    scroll_to page.find("div#password-container", visible: false)
    expect(page).to have_selector(:link_or_button, I18n.t('preboard.landing.create_account'), disabled: true)
  end

  def user_can_set_password_in_landing
    scroll_to page.find("div#password-container", visible: false)
    fill_in :password, with: nick.password
    expect(page).to have_selector(:link_or_button, I18n.t('preboard.landing.create_account'), disabled: false)
    wait_all_requests
    wait(1)
    click_on I18n.t('preboard.landing.create_account')
    wait_all_requests
  end

  def user_can_complete_welcome
    expect(page).to have_text I18n.t('preboard.welcome', company: company.name)
    expect(page).to have_text I18n.t('preboard.begin.title', {first_name: nick.company.operation_contact&.first_name})
    expect(page).to have_text I18n.t('notifications.admin.company.welcome_note')
    click_button "BEGIN PREBOARDING"
    wait_all_requests
  end

  def user_can_complete_our_story
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.our_story.title', company: company.name)
    expect(page).to have_text(company.company_video)
    scroll_to page.first("ms-card")
    expect(page).to have_text(milestone.happened_at.strftime('%B %Y'))
    expect(page).to have_text(milestone.name)
    expect(page).to have_text(milestone.description)
    expect(page).to have_text(company_value.name)
    expect(page).to have_text(company_value.description)
    click_button I18n.t('preboard.next')
    wait 4
  end

  def user_can_complete_your_team
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.people.team_members.title')
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.people.onboarding_class')
    click_button I18n.t('preboard.next')
    wait_all_requests
  end

  def user_can_complete_your_profile
    expect(page).to have_text I18n.t('preboard.about_you.profile_photo')
    upload_profile_image
    fill__Public_Profile
    fill_personal
    fill_addition
    fill_private
    click_button('Submit')
    wait_all_requests
  end

  def user_can_complete_wrap_up
    expect(page).to have_text I18n.t('preboard.wrapup.title')
    page.find("#welcome-checkbox")[:class].include?("md-checked")
    page.find("#story-checkbox")[:class].include?("md-checked")
    page.find("#people-checkbox")[:class].include?("md-checked")
    page.find("#about-checkbox")[:class].include?("md-checked")
    sleep(1)
    click_on I18n.t('preboard.wrapup.goto')
    wait_all_requests
  end

  def user_can_see_congratulations
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.congrats.all_done')
    click_on I18n.t('preboard.congrats.continue')
    wait_all_requests
    expect(page).to have_text I18n.t('onboard.home.profile.profile')
  end

  def upload_profile_image
    scroll_to page.find("#upload-photo")
    attach_ng_file('profile_image', Rails.root.join("spec/factories/uploads/users/profile_image/nick.jpg"), controller: "about_you")
    wait_all_requests
    expect(page).to have_text('Adjust Your Photo')
    expect(page).to have_text('Drag, zoom or rotate your image to your preferred specifications')
    wait_all_requests
    click_button 'Rotate'
    wait_all_requests
    click_button 'Save'
    wait_all_requests
    click_button 'Cancel'
    wait_all_requests
  end

  def fill_personal
    expect(find_field('first_name').value).to eq nick.first_name
    expect(page).to have_css("div span", :text => "coworker *")
    expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='personal_info_form']/button/span", text: I18n.t('preboard.our_story.next').upcase)
    choose_item_from_autocomplete('coworker', "#{maria.first_name} #{maria.last_name}")
    expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='personal_info_form']/button/span", text: I18n.t('preboard.our_story.next').upcase)
    expect(find_field('last_name').value).to eq nick.last_name
    fill_in :preferred_name, with: nick.preferred_name
    fill_in :home_phone_number, with: Faker::Number.number(10).to_i
    fill_in :mobile_phone_number, with: Faker::Number.number(10).to_i
  end

  def fill__Public_Profile
    fill_in :about_you, with: profile_attributes[:about_you]
    fill_in :linkedin, with: profile_attributes[:linkedin]
    fill_in :twitter, with: profile_attributes[:twitter]
    fill_in :github, with: profile_attributes[:github]
    click_on I18n.t('preboard.next')
  end

  def fill_addition
    fill_in :'food_allergies/preferences', with: "None"
    fill_in :dream_vacation_spot, with: Faker::Hipster.sentence
    expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='additional_info_form']/button/span", text: I18n.t('preboard.our_story.next').upcase)
    fill_in :favorite_food, with: Faker::Hipster.sentence
    fill_in :pets_and_animals, with: Faker::Hipster.sentence
    expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='additional_info_form']/button/span", text: I18n.t('preboard.our_story.next').upcase)
    choose_item_from_dropdown("t-shirt_size", "Large")
  end

  def fill_private
    fill_in :social_security_number, with: "691-27-1293"
    choose_item_from_dropdown('federal_marital_status','Single')
    expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='private_info_form']/button/span", text: I18n.t('preboard.our_story.next').upcase)
    sleep(1)

    page.execute_script("$('md-datepicker input').val('12/12/2007').trigger('input')")
    fill_in :home_address_line_1, with: Faker::Address.street_address
    fill_in :home_address_line_2, with: Faker::Address.street_address
    fill_in :home_address_city, with: Faker::Address.city
    choose_first_item_from_dropdown("home_address_country")
    choose_first_item_from_dropdown("home_address_state")
    fill_in :home_address_zip, with: '32335'
    choose_item_from_dropdown("gender", "Female")
    choose_item_from_dropdown('race/ethnicity','Asian')
    fill_in :emergency_contact_name, with: Faker::Name.first_name
    choose_item_from_dropdown('emergency_contact_relationship','Father')
    expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='private_info_form']/button/span", text: I18n.t('preboard.our_story.next').upcase)
    sleep(1)

    scroll_to page.find('[name="emergency_contact_number"]')
    fill_in :emergency_contact_number, with: Faker::Number.number(10).to_i

  end

  def user_can_see_short_password_message
    scroll_to page.find("div#password-container", visible: false)
    fill_in :password, with: "pass123"
    fill_in :password_confirmation, with: "pass123"
    expect(page).to have_text I18n.t('preboard.landing.errors.pass_short')
    expect(page).to have_selector(:link_or_button, I18n.t('preboard.landing.create_account'), disabled: true)
  end

  def user_can_see_password_do_not_match_messsage
    scroll_to page.find("div#password-container", visible: false)
    fill_in :password, with: ENV['USER_PASSWORD']
    fill_in :password_confirmation, with: ENV['USER_PASSWORD']
    page.execute_script("$('div').trigger('focus')")
    expect(page).to have_text I18n.t('preboard.landing.errors.pass_not_match')
    expect(page).to have_selector(:link_or_button, I18n.t('preboard.landing.create_account'), disabled: true)
  end
