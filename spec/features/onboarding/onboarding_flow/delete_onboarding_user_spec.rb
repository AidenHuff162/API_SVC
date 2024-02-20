require 'feature_helper'

feature 'Dashboard Testcases', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:location) { create(:location, company: company) }
  given!(:team) { create(:team, company: company) }
  given!(:team1) { create(:team, company: company) }
  given!(:team2) { create(:team, company: company) }
  given!(:team3) { create(:team, company: company) }
  given!(:team4) { create(:team, company: company) }
  given!(:team5) { create(:team, company: company) }
  given!(:team6) { create(:team, company: company) }
  given!(:team7) { create(:team, company: company) }
  given!(:sarah) { create(:sarah, company: company, preferred_name: '', team_id:team.id) }
  given!(:nick) { create(:nick, company: company,  preferred_name: '', team_id:team1.id) }
  given!(:addys) { create(:addys, company: company, preferred_name: '', team_id:team2.id) }
  given!(:agatha) { create(:agatha, company: company, preferred_name: '', team_id:team3.id) }
  given!(:hilda) { create(:hilda, company: company, preferred_name: '', team_id:team4.id) }
  given!(:tim) { create(:tim, company: company, preferred_name: '', team_id:team5.id) }
  given!(:maria) { create(:maria, company: company, preferred_name: '', team_id:team6.id) }
  given!(:taylor) { create(:taylor, company: company,  preferred_name: '', team_id:team7.id) }

  background { Auth.sign_in_user maria, maria.password }

  describe 'Delete Onboarding Users From Dashboard' do
    scenario 'Delete onboarding users with different users states' do
      navigate_to_dashbaord
      delete_users
    end
  end
end
