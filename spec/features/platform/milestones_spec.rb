require 'feature_helper'

feature 'Milestones', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:user) { create(:user, company: company, role: :account_owner, preferred_name: "") }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:location) { create(:location, company: company) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Steps to add milestones and verify dates' do

    scenario 'Add milestone and check milestone edit date for USA (mm/dd/yyyy)' do
      navigate_to_platform
      change_date_format_to_usa
      navigate_to_milestones
      add_milestone "%m/%d/%Y"
      check_milestone_edit_date_for_usa
    end

    scenario 'Add milestone and check milestone edit date for International (dd/mm/yyyy)' do
      navigate_to_platform
      change_date_format_to_International
      navigate_to_milestones
      add_milestone "%d/%m/%Y"
      check_milestone_edit_date_for_International
    end

    scenario 'Add milestone and check milestone edit date for ISO 8601 (yyyy/mm/dd)' do
      navigate_to_platform
      change_date_format_to_ISO_8601
      navigate_to_milestones
      add_milestone "%Y/%m/%d"
      check_milestone_edit_date_for_ISO_8601
    end

    scenario 'Add milestone and check milestone edit date for Long Date' do
      navigate_to_platform
      change_date_format_to_Long_Date
      navigate_to_milestones
      add_milestone "%B %d, %Y"
      check_milestone_edit_date_for_Long_Date
    end
  end
end
