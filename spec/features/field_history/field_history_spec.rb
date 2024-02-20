require 'feature_helper'

feature 'Sarah can verify the employee_record fields.', type: :feature, js: true do
  given!(:milestone) { build(:milestone) }
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:user) { create(:user, company: company, role: :account_owner, preferred_name: "", current_stage: :registered) }
  given!(:company_value) { build(:company_value) }
  given!(:team) { create(:team, company: company) }
  given(:user_attributes) { attributes_for(:user) }
  given!(:location) { create(:location, company: company) }
  given!(:sarah) { create(:sarah, company: company) }
  given!(:tim) { create(:tim, company: company, preferred_name: "") }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }
  given(:user_attributes) { attributes_for(:user) }

  background { Auth.sign_in_user sarah, sarah.password }
  
  describe 'Login with sarah and verify the functionality' do
    scenario 'Verify the field history from user info' do
      navigate_to_employee_record_for_user
      personal_field_validation
      additional_field_validation
      private_field_validation
    end
  end
end
