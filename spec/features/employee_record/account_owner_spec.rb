require 'feature_helper'

feature 'Employee Record', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:user) { create(:user, company: company, role: :account_owner, preferred_name: "", current_stage: :registered) }
  given!(:sarah) { create(:sarah, company: company, role: :account_owner, preferred_name: "") }
  given!(:location) { create(:location, company: company) }

  given!(:manager) { create(:user, company: company, preferred_name: "") }
  given!(:buddy) { create(:user, company: company, preferred_name: "") }
  given!(:team) { create(:team, company: company) }

  given(:user_attributes) { attributes_for(:user) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe " Step's to  Enter Employee Record " do
    background {
      wait_all_requests
    }

    scenario " Account owner can enter or update Employee Record " do
      navigate_to_employee_record_tab
      account_owner_personal_information
      verify_account_owner_personal_information
      account_owner_additional_information
      verify_account_owner_additional_information
      account_owner_private_information
      verify_account_owner_private_information
      account_owner_profile_information
      verify_account_owner_profile_information
    end
  end
end
