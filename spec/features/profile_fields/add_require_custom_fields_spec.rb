require 'feature_helper'

feature 'Profile Fields', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo', is_using_custom_table: false) }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "", seen_profile_setup: true) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Custom Fields' do
    scenario 'Create Require Custom Field In Profile Information Section For Onboarding Process' do
      navigate_to_profile_fields
      create_require_custom_field('Admin')
    end

    scenario 'Verify Default Profile Fields' do
      navigate_to_profile_fields
      verify_default_custom_fields
    end

    scenario 'Edit And Verify Profile Fields' do
      navigate_to_profile_fields
      create_require_custom_field('Admin')
      edit_custom_fields
      delete_custom_fields
    end
  end
end
