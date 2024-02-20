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

  scenario 'Create new group type and add groups in it' do
    navigate_to_groups
    add_new_group_type
    add_new_group_in_new_type
    set_active_user_new_group_type
    set_inactive_user_new_group_type
    navigate_to_groups
    verify_active_and_inactive_count_of_new_group
    disable_new_group_toggle
    verify_new_group_toggle_for_active_user
    verify_new_group_toggle_for_inactive_user
    navigate_to_groups
    edit_new_group_type
    delete_new_group_type
  end
end