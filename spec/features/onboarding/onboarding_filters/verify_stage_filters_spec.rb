require 'feature_helper'

feature 'Onboarding Dashboard', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "Sarah") }
  given!(:hilda) { create(:hilda, company: company, preferred_name: "Hilda", team_id: team1.id, location_id: location1.id) }
  given!(:agatha) { create(:agatha, company: company, preferred_name: "Agatha", team_id: team2.id, location_id: location2.id) }
  given!(:addys) { create(:addys, company: company, preferred_name: "Addys", team_id: team3.id, location_id: location3.id) }
  given!(:taylor) { create(:taylor, company: company, preferred_name: "Taylor", team_id: team4.id, location_id: location4.id) }
  given!(:tim) { create(:tim, company: company, preferred_name: "Tim", team_id: team5.id, location_id: location5.id) }
  given!(:williams) { create(:williams, company: company, preferred_name: "Williams", team_id: team6.id, location_id: location6.id) }
  given!(:location1) { create(:location, name: "Lahore", company: company) }
  given!(:location2) { create(:location, name: "Hyderabad", company: company) }
  given!(:location3) { create(:location, name: "America", company: company) }
  given!(:location4) { create(:location, name: "London", company: company) }
  given!(:location5) { create(:location, name: "Paris", company: company) }
  given!(:location6) { create(:location, name: "France", company: company) }
  given!(:team1) { create(:team, name: "QA", company: company) }
  given!(:team2) { create(:team, name: "Developer", company: company) }
  given!(:team3) { create(:team, name: "Designer", company: company) }
  given!(:team4) { create(:team, name: "Support", company: company) }
  given!(:team5) { create(:team, name: "Customer Success", company: company) }
  given!(:team6) { create(:team, name: "Sales", company: company) }
  given!(:welcome) { create(:welcome, company: company) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

  scenario 'Verify Stage Filters' do
    # navigate_to_dashboard
    # verify_users_count_on_dashboard
    # filter_users_by_stage('All Stages','Invited')
    # filter_users_by_stage('Invited','Preboarding')
    # filter_users_by_stage('Preboarding','Pre-Start')
    # filter_users_by_stage('Pre-Start','1st Week')
    # filter_users_by_stage('1st Week','1st Month')
    # filter_users_by_stage('1st Month','Ramping Up')
  end
end
