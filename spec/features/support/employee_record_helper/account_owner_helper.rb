def account_owner_personal_information
    wait(2)

    fill_in :first_name, with: user_attributes[:first_name]
    fill_in :last_name, with: user_attributes[:last_name]
    fill_in :company_email, with: sarah.email
    fill_in :personal_email, with: sarah.personal_email
    wait(1)
    wait_all_requests
    find('.start_date .md-datepicker-button').trigger('click')
    wait(2)
    page.execute_script('$(".md-calendar [md-calendar-month-body]:nth-child(4) .md-focus").click()')
    wait_all_requests
    choose_item_from_dropdown('access_permission','Super Admin')
    wait(1)
    fill_in :home_phone_number,     with: '03009876543'
    fill_in :mobile_phone_number,   with: '03001234567'
    wait(1)

    page.execute_script("$[button:contains('Save'):enabled].click()")
    wait_all_requests
end

def verify_account_owner_personal_information
    expect(find("input[name='first_name']").value).to eq(user_attributes[:first_name])
    expect(find("input[name='last_name']").value).to eq(user_attributes[:last_name])
    expect(find("input[name='company_email']").value).to eq(sarah.email)
    expect(find("input[name='personal_email']").value).to eq(sarah.personal_email)
    expect(page).to have_content('Super Admin')
    expect(find("input[name='home_phone_number']").value).to eq('03009876543')
    expect(find("input[name='mobile_phone_number']").value).to eq('03001234567')
end

def account_owner_additional_information
    wait_all_requests
    fill_in :'food_allergies/preferences',  with:'Rice'
    wait_all_requests
    fill_in :'dream_vacation_spot',  with: 'London'
    wait_all_requests
    fill_in :'favorite_food',  with:'Pizza'
    wait_all_requests
    fill_in :'pets_and_animals',  with:'Dogs'
    choose_item_from_dropdown('t-shirt_size','X-Large')
    page.execute_script("$[button:contains('Save'):enabled].click()")
end

def verify_account_owner_additional_information
    expect(find("input[name='food_allergies/preferences']").value).to eq('Rice')
    expect(find("input[name='dream_vacation_spot']").value).to eq('London')
    expect(find("input[name='favorite_food']").value).to eq('Pizza')
    expect(find("input[name='pets_and_animals']").value).to eq('Dogs')
    expect(page).to have_content('X-Large')
end

def account_owner_private_information
    wait(1)
    find('[name="social_security_number"]').set("323333333")

    choose_item_from_dropdown('federal_marital_status','Single')
    wait(1)
    scroll_to page.find('[name="home_address_city"]', visible: false)
    add_to_date_picker('date_of_birth','05-22-1993')

    fill_in :'home_address_line_1', with: 'Headquarters 1120 N'
    fill_in :'home_address_line_2', with: 'Street Sacramento'
    scroll_to page.find('[name="home_address_city"]', visible: false)

    wait_all_requests
    wait(1)
    fill_in :'home_address_city',    with: 'Caltrans'

    choose_item_from_dropdown('home_address_state','AL')
    wait(1)
    fill_in :'home_address_zip',	with: '32335'

    scroll_to page.find('[name="emergency_contact_number"]', visible: false)

    choose_item_from_dropdown('gender','Male')
    wait(1)
    choose_item_from_dropdown('race/ethnicity','Asian')

    fill_in :emergency_contact_name, with: user_attributes[:first_name]
    choose_item_from_dropdown('emergency_contact_relationship','Father')
    wait(1)
    fill_in :emergency_contact_number, with:'03001234567'

    page.execute_script("$[button:contains('Save'):enabled].click()")

end

def verify_account_owner_private_information
    expect(find("input[name='social_security_number']").value).to eq('323-33-3333')
    expect(find("input[name='home_address_line_1']").value).to eq('Headquarters 1120 N')
    expect(find("input[name='home_address_line_2']").value).to eq('Street Sacramento')
    expect(find("input[name='home_address_zip']").value).to eq('32335')

    expect(page).to have_content('Single')
    expect(page).to have_content('Male')
end

def account_owner_profile_information
    find('md-tab-item',:text => I18n.t('onboard.home.toolbar.profile')).trigger('click')
    wait_all_requests

    fill_in :'about_you', with: 'What about me'
    fill_in :'linkedin', with: 'linkedin.com/profile'

    fill_in :'twitter', with: 'twitter.com/profile'
    fill_in :'github', with: 'github.com/profile'
    page.execute_script("$[button:contains('Save'):enabled].click()")
end

def verify_account_owner_profile_information
    expect(find("textarea[name='about_you']").value).to eq('What about me')
    expect(find("input[name='linkedin']").value).to eq('linkedin.com/profile')
    expect(find("input[name='twitter']").value).to eq('twitter.com/profile')
    expect(find("input[name='github']").value).to eq('github.com/profile')
end
