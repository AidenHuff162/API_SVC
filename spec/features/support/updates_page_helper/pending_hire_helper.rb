
def navigate_to_pending_updates
    wait_all_requests
    navigate_to "/#/updates"
    wait(2)
end

def navigate_to_update_onboard
	wait_all_requests
    click_button ("ONBOARD NEW HIRE")
end

def create_user_profile_for_pending_hire
    wait_all_requests
    fill_in :first_name, with: 'Testing'
    fill_in :last_name, with: user_attributes[:last_name]
    fill_in :personal_email, with: Faker::Internet.user_name + '@test.com'

    fill_in :email, with: Faker::Internet.user_name + '@foo.com'
    wait_all_requests
    choose_item_from_autocomplete('job_title', "Head of Operations")
    scroll_to page.find('#date', visible: false)

    page.find('#date .md-datepicker-triangle-button').trigger('click')
    wait_all_requests
    page.find('.md-focus').trigger('click')
    wait(1)

    choose_item_from_autocomplete_smart('employee_type','Full Time')
    choose_item_from_autocomplete_smart('location', location.name)
    choose_item_from_autocomplete_smart('manager', "#{sarah.preferred_name} #{sarah.last_name}")
    choose_item_from_autocomplete_smart('team',team.name)

    wait_all_requests
    click_on I18n.t('log_in.save')
    wait(2)

    navigate_to "/#/pending_hire"
    wait_all_requests

    click_button ("EXIT")
    wait_all_requests

end

def create_user_profile_for_pending_hire_2
    wait_all_requests
    fill_in :first_name, with: user_attributes[:first_name]
    fill_in :last_name, with: user_attributes[:last_name]
    fill_in :personal_email, with: Faker::Internet.user_name + '@test.com'

    fill_in :email, with: Faker::Internet.user_name + '@foo.com'
    wait_all_requests
    choose_item_from_autocomplete('job_title', "Head of Operations")
    scroll_to page.find('#date', visible: false)

    page.find('#date .md-datepicker-triangle-button').trigger('click')
    wait_all_requests
    page.find('.md-focus').trigger('click')
    wait(1)

    choose_item_from_autocomplete_smart('employee_type','Full Time')
    choose_item_from_autocomplete_smart('manager', "#{sarah.preferred_name} #{sarah.last_name}")
    choose_item_from_autocomplete_smart('team',team.name)
    choose_item_from_autocomplete_smart('location', location.name)
    
    wait_all_requests
    click_on I18n.t('log_in.save')
    wait(2)

    navigate_to "/#/pending_hire"
    wait_all_requests

    click_button ("EXIT")
    wait_all_requests

end

def view_all_pendings
	navigate_to "/#/updates"
    wait_all_requests
    click_button("VIEW ALL")
    # expect(page).to have_content("2 people")
end
