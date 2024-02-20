require 'feature_helper'

feature 'Preboarding', type: :feature, js: true do
  given!(:milestone) { build(:milestone) }
  given!(:company_value) { build(:company_value) }
  given!(:company) do
    create(:company,
      subdomain: 'foo',
      company_video: 'fake company video html',
      company_values: [company_value],
      milestones: [milestone]
    )
  end
  given!(:sarah) { create(:sarah, company: company, onboarding_profile_template_id: company.profile_templates.first.try(:id)) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }
  given!(:profile_attributes) { attributes_for(:profile) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Unchecked Profile Fields And Verify Preboarding' do
    scenario 'Unchecked Require Fields And Verify Preboarding Functionality' do
      navigate_to_employee_record
      uncheck_require_fields
      navigate_to_preboarding
      verify_our_story_page
      verify_your_team_page
      verify_complete_your_profile_page
      verify_congratulations_dialog
    end
  end
end
