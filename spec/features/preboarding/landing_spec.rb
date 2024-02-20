require 'feature_helper'

feature 'Nick can complete preboarding. ', type: :feature, js: true do
  given!(:milestone) { build(:milestone) }
  given!(:company_value) { build(:company_value) }
  given!(:user_email) { create(:user_email, user: nick) }
  given!(:invite) { create(:invite, user_email: user_email) }

  given!(:company) do
    create(:company_with_operation_contact,
      subdomain: 'foo',
      company_video: 'fake company video html',
      company_values: [company_value],
      milestones: [milestone],
      notifications_enabled: true,
      preboarding_complete_emails: true
    )
  end


  given!(:sarah) { create(:sarah, company: company) }
  given!(:nick) { create(:nick, company: company, manager: sarah) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }
  given!(:profile_attributes) { attributes_for(:profile) }


  background {
      navigate_to "/#/invite/#{invite.token}"
      wait_all_requests
    }

  describe 'User comes via invite' do

    scenario 'and can complete preboarding with welcome note.' do
      user_can_complete_landing_step
      user_can_complete_welcome_step
      user_can_complete_our_story_step
      user_can_complete_your_team
      user_can_complete_your_profile
      wait_all_requests
      user_can_see_congratulations_dialog
    end
  end

  def user_can_complete_landing_step
    check_user_has_reached_landing_page
    user_can_set_password_in_landing_page
  end

  def check_user_has_reached_landing_page
    expect(page).to have_text I18n.t('preboard.landing.welcome.title', name: nick.first_name)
    scroll_to page.find("div#password-container", visible: false)
    expect(page).to have_selector(:link_or_button, I18n.t('preboard.landing.create_account'), disabled: true)
  end

  def user_can_set_password_in_landing_page
    scroll_to page.find("div#password-container", visible: false)
    fill_in :password, with: nick.password
    expect(page).to have_selector(:link_or_button, I18n.t('preboard.landing.create_account'), disabled: false)
    wait_all_requests
    wait(1)
    click_on I18n.t('preboard.landing.create_account')
    wait_all_requests
  end

  def user_can_complete_welcome_step
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.begin.title', {first_name: company.operation_contact&.preferred_name})
    expect(page).to have_text I18n.t('notifications.admin.company.welcome_note')
    click_button "BEGIN PREBOARDING"
    wait_all_requests
  end

  def user_can_complete_our_story_step
    expect(page).to have_text I18n.t('preboard.our_story.title', company: company.name)
    expect(page).to have_text(company.company_video)
    scroll_to page.first("ms-card")
    expect(page).to have_text(milestone.happened_at.strftime('%B %Y'))
    expect(page).to have_text(milestone.name)
    expect(page).to have_text(milestone.description)
    expect(page).to have_text(company_value.name)
    expect(page).to have_text(company_value.description)
    click_button I18n.t('preboard.next')
    wait_all_requests
  end

  def user_can_complete_your_team
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.people.team_members.title')
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.people.onboarding_class')
    click_button I18n.t('preboard.next')
    wait_all_requests
  end

  def complete_Your_Public_Profile
    fill_in :about_you, with: profile_attributes[:about_you]
    fill_in :linkedin, with: profile_attributes[:linkedin]
    fill_in :twitter, with: profile_attributes[:twitter]
    fill_in :github, with: profile_attributes[:github]
    click_on I18n.t('preboard.next')
  end

  def user_can_complete_your_profile
    expect(page).to have_text I18n.t('preboard.about_you.profile_photo')
    upload_profile_image
    complete_Your_Public_Profile
    fill_personal_info
    fill_addition_info
    fill_private_info
    click_button('Submit')
    wait_all_requests
  end

  def user_can_see_congratulations_dialog
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.congrats.all_done')
    wait_all_requests
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

  def fill_personal_info
    wait_all_requests
    expect(page).to have_text I18n.t('preboard.your_info.complete')
    expect(find_field('first_name').value).to eq nick.first_name
    expect(find_field('last_name').value).to eq nick.last_name
    expect(find_field('preferred_name').value).to eq nick.preferred_name
    fill_in :preferred_name, with: nick.preferred_name
    fill_in :home_phone_number, with: Faker::Number.number(10).to_i
    fill_in :mobile_phone_number, with: Faker::Number.number(10).to_i
    wait_all_requests
  end

  def fill_addition_info
    wait_all_requests
    fill_in :'food_allergies/preferences', with: "None"
    fill_in :dream_vacation_spot, with: Faker::Hipster.sentence
    expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='additional_info_form']/button/span", text: I18n.t('preboard.our_story.next').upcase)
    fill_in :favorite_food, with: Faker::Hipster.sentence
    fill_in :pets_and_animals, with: Faker::Hipster.sentence
    expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='additional_info_form']/button/span", text: I18n.t('preboard.our_story.next').upcase)
    choose_item_from_dropdown("t-shirt_size", "Large")
    wait_all_requests
  end

  def fill_private_info
    wait_all_requests
    fill_in :social_security_number, with: "691-27-1292"
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
    choose_item_from_dropdown("race/ethnicity", "Asian")
    fill_in :emergency_contact_name, with: Faker::Name.first_name
    choose_item_from_dropdown('emergency_contact_relationship','Father')
    expect(page).to have_no_selector(:xpath, "//ms-vertical-stepper-step[@id='private_info_form']/button/span", text: I18n.t('preboard.our_story.next').upcase)
    sleep(1)

    scroll_to page.find('[name="emergency_contact_number"]')
    fill_in :emergency_contact_number, with: Faker::Number.number(10).to_i
    wait_all_requests
  end

  def user_can_see_short_password_message
    scroll_to page.find("div#password-container", visible: false)
    fill_in :password, with: ENV['USER_PASSWORD']
    fill_in :password_confirmation, with: ENV['USER_PASSWORD']
    expect(page).to have_text I18n.t('preboard.landing.errors.pass_short')
    expect(page).to have_selector(:link_or_button, I18n.t('preboard.landing.create_account'), disabled: true)
  end

  def user_can_see_password_do_not_match_messsage
    scroll_to page.find("div#password-container", visible: false)
    fill_in :password, with: ENV['USER_PASSWORD']
    fill_in :password_confirmation, with: "pass12345"
    page.execute_script("$('div').trigger('focus')")
    expect(page).to have_text I18n.t('preboard.landing.errors.pass_not_match')
    expect(page).to have_selector(:link_or_button, I18n.t('preboard.landing.create_account'), disabled: true)
  end
end
