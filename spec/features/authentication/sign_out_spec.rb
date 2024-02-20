require 'feature_helper'

feature 'User can sign out', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:user) { create(:user, company: company, current_stage: :registered) }

  background { Auth.sign_in_user user }

  describe 'User can sign out when he is signed in' do
    scenario 'User sees sign in page' do
      find("#user-menu").click
      click_on t('admin.header.sign_out')

      expect(page).to have_content('Welcome Back')
    end
  end
end
