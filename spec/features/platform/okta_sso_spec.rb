require 'feature_helper'

feature 'SSO Management', type: :feature, js: true do
  given(:password) { ENV['TEST_PASSWORD'] }
  given!(:company) { create(:company, subdomain: 'foo')}
  given!(:user) { create(:user, company: company, password: password, current_stage: User.current_stages[:registered]) }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "", start_date: Date.today) }
  given!(:hilda) { create(:hilda, company: company, preferred_name: "") }
  given!(:inactive_user) { create(:user, company: company, password: password, state: 'inactive') }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Okta_SSO' do
    scenario 'Allow sign in with password and okta_sso' do
      naviagete_to_integrations
      enable_okta_sso
      navigate_to_platform
      navigate_to_sso
      select_paasword_and_sso
      sign_out
      check_login_page_for_password_and_okta_sso
      check_email_format
      check_inactive_user
      check_logged_in_after_multiple_failed_attempts
      check_sso_management_after_disabling_okta_sso_integration
      sign_out
      check_login_page_for_password_only
    end

    scenario 'Allow sign in with okta_sso only' do
      naviagete_to_integrations
      enable_okta_sso
      navigate_to_platform
      navigate_to_sso
      select_sso_only
      sign_out
      check_login_page_for_okta_sso_only
      sign_out
      check_login_page_for_password_and_okta_sso
      check_email_format
      check_inactive_user
    end
  end
end
