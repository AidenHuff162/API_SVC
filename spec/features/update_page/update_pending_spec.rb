require 'feature_helper'

feature 'Onboard New User', type: :feature, js: true do
  given!(:company) { create(:rocketship_company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "Sarah") }
  given!(:location) { create(:location, company: company) }

  given!(:manager) { create(:user, company: company, preferred_name: "") }
  given!(:buddy) { create(:user, company: company, preferred_name: "") }
  given!(:team) { create(:team, company: company) }

  given(:user_attributes) { attributes_for(:user) }
  given(:profile_attributes) { attributes_for(:profile) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Step Create Profile' do
    scenario 'Pending hires on updates page' do
      navigate_to_pending_updates
      navigate_to_update_onboard
      create_user_profile_for_pending_hire
      navigate_to_pending_updates
      navigate_to_update_onboard
      create_user_profile_for_pending_hire_2
      view_all_pendings


    end
  end
end
