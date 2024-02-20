require 'feature_helper'

feature 'Employee Record', type: :feature, js: true do
  before { Company.with_deleted.each { |c| c.update_column(:subdomain, c.subdomain + Time.now.to_s)}}
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:manager) { create(:user, company: company, preferred_name: "") }
  given!(:buddy) { create(:user, company: company, preferred_name: "") }
  given!(:tim) { create(:tim, role: :employee, company: company, preferred_name: "") }
  given!(:location) { create(:location, company: company) }

  given!(:team) { create(:team, company: company) }

  given(:user_attributes) { attributes_for(:user) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user tim, tim.password }

  describe "Step's to  enter Employee Record" do
    
    background {
      wait_all_requests
    }
    
    scenario "Employee can enter or update own Employee Record" do
      navigate_to_employee_record_tab
      employee_personal_information
    end
  end
end
