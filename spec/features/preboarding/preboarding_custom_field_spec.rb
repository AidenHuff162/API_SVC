require 'feature_helper'

feature 'Preboarding', type: :feature, js: true do
  given!(:milestone) { build(:milestone) }
  given!(:company_value) { build(:company_value) }
  given!(:invite) { create(:invite, user: nick) }
  given!(:company) do
    create(:company,
      subdomain: 'foo',
      company_video: 'fake company video html',
      company_values: [company_value],
      milestones: [milestone]
    )
  end

  given!(:coworker) do
    create(:custom_field,
          company: company,
          name: "coworker",
          section: 0,
          field_type: 11,
          collect_from: 0,
          required: true,
          position: 0,
          help_text: "Add Co-worker",
          required_existing: true
          )
      end
  given!(:sarah) { create(:sarah, company: company) }
  given!(:nick) { create(:nick, company: company) }
  given!(:maria) { create(:maria, company: company, preferred_name: nil) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }
  given!(:profile_attributes) { attributes_for(:profile) }

  background {
      navigate_to "/#/invite/#{invite.token}"
      wait_all_requests
    }

  describe 'Preboarding with Custom fields' do
    # scenario 'Create Custom Field And Complete Preboarding' do
    #   user_can_complete_landing
    #   user_can_complete_our_story
    #   user_can_complete_your_team
    #   user_can_complete_your_profile
    #   user_can_see_congratulations
    # end
  end
end
