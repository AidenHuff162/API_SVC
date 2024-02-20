require 'feature_helper'

feature 'comapany links', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:user) { create(:user, company: company, role: :account_owner, preferred_name: "") }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:location) { create(:location, company: company) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

#      scenario 'Add Company_links And Verify In Updates Page' do
#       navigate_to_platform
#       click_on_company_links
#       add_company_links
#       navigate_to_updates
#       verify_company_links
#     end
#      scenario 'Add Company_links And Delete' do
#       navigate_to_platform
#       click_on_company_links
#       add_company_links
#       delete_company_links
#     end
#      scenario 'Add Company_links And Update' do
#       navigate_to_platform
#       click_on_company_links
#       add_company_links
#       update_company_links
#     end
  end
