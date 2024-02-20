require 'feature_helper'

feature 'Groups', type: :feature, js: true do
  given(:password) { ENV['TEST_PASSWORD'] }
  given!(:company) { create(:company, subdomain: 'foo')}
  given!(:user) { create(:user, company: company, password: password, current_stage: User.current_stages[:registered]) }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "", start_date: Date.today) }
  given!(:nick) { create(:nick, company: company, preferred_name: "", current_stage: 'registered', start_date: 6.years.ago, manager_id:sarah.id) }
  given!(:tim) { create(:tim, company: company, preferred_name: "", current_stage: 'registered', start_date: 6.years.ago, manager_id:sarah.id) }
  given!(:peter) { create(:peter, company: company, preferred_name: "", current_stage: 'departed' , manager_id:sarah.id, state: 'inactive') }
  given!(:addys) { create(:addys, company: company, preferred_name: "", current_stage: 'departed' , manager_id:sarah.id, state: 'inactive') }
  background { Auth.sign_in_user sarah, sarah.password }

  scenario 'Create Departments and Locations and verify their active and inactive members' do
    navigate_to_groups
    add_new_department
    add_new_location
    set_active_user_department_and_location
    set_inactive_user_department_and_location
    navigate_to_groups
    verify_active_and_inactive_count_of_department
    verify_active_and_inactive_count_of_location
    disable_department_and_location_toggle
    verify_department_and_location_toggle_for_active_user
    verify_department_and_location_toggle_for_inactive_user
  end
end