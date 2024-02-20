require 'feature_helper'

feature 'Reports Test Cases', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:user) { create(:user, company: company, role: :account_owner, preferred_name: "") }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:location1) { create(:location, company: company) }
  given!(:location2) { create(:location, company: company) }
  given!(:team1) { create(:team, company: company) }
  given!(:team2) { create(:team, company: company) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Create Reports and verify its functionality' do
    scenario 'Build, save custom reports'do
      navigate_to_reports
      create_new_report
      choose_fields
      filter_sort
      verify_reports_fields
      edit_report
    end
  end
end
