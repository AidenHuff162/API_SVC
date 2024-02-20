
def navigate_to_user_tasks
    wait_all_requests
    navigate_to "/#/tasks/"+tim.id.to_s
    wait(2)
end

def navigate_to_other_user_tasks
    wait_all_requests
    navigate_to "/#/tasks/"+taylor.id.to_s
    wait(2)
end


def expand_program_management_panel
    page.find('expansion-panel[title="Program Management"] .collapsed-div').trigger('click')
    wait_all_requests
    expect(page).to have_content ('There are 5 active transitions and 12 activities to complete')
    expect(page).to have_content ('4 people onboarding')
    expect(page).to have_content ('1 people offboarding')
    expect(page).to have_content ('12 outstanding activities from 2 people')
    expect(page).to have_content ('0 overdue activities from 0 people')
end


def assign_tasks_for_program_management
    click_button ("Assign Workflow")
    wait_all_requests
    page.execute_script("$('md-checkbox:first .md-ink-ripple').click()")
    click_button ("Next")
    wait_all_requests
    click_button ("Next")
    wait_all_requests
    wait(1)
    click_button ("Finish")
    wait_all_requests
end


def offboard_user_for_program_management
    navigate_to "/#/admin/offboard"
    wait_all_requests
    choose_item_from_autocomplete('employee_name', "#{maria.preferred_name} #{maria.last_name}")
    choose_item_from_dropdown('termination_type','Voluntary')
    choose_item_from_dropdown('eligible_rehire','Yes')
    termination_date = (Date.today + 1.days).strftime("%m/%d/%Y")
    page.execute_script("$('.termination_date .md-datepicker-input').val('#{termination_date}').trigger('input')")
    wait_all_requests

    last_day_date = (Date.today + 1.days).strftime("%m/%d/%Y")
    page.execute_script("$('.last_day_date .md-datepicker-input').val('#{last_day_date}').trigger('input')")
    wait_all_requests
    
    choose_item_from_autocomplete_smart('location', location.name)
    choose_item_from_autocomplete_smart('employee_type','Full Time')
    choose_item_from_autocomplete_smart('team',team.name)
    
    wait_all_requests

    click_button I18n.t('admin.offboard.next_step')
    wait_all_requests

    click_button('Save & Continue')
    wait_all_requests

    click_button I18n.t('admin.offboard.skip_step_three')
    wait_all_requests
end

def onboard_people_CTA
    page.find('expansion-panel[title="Program Management"] #onboard_count').trigger('click')
    wait_all_requests
    expect(page).to have_content ('Dashboard')
    expect(page).to have_content ('4 Team Members')
end


def offboard_people_CTA
    page.find('expansion-panel[title="Program Management"] #offboard_count').trigger('click')
    wait_all_requests
    expect(page).to have_content ('Dashboard')
    expect(page).to have_content ('1 Team Members')
end


def open_tasks_CTA
    wait_all_requests
    page.find('expansion-panel[title="Program Management"] #open_activity_count').trigger('click')
    wait_all_requests
    expect(page).to have_content ('12 Open Tasks')
    expect(page).to have_content ('All Open Tasks')
end


def overdue_tasks_CTA
    wait_all_requests
    page.find('expansion-panel[title="Program Management"] #overdue_activity_count').trigger('click')
    wait_all_requests
    expect(page).to have_content ('0 overdue activities')
end
