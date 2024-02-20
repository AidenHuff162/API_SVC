def naviagete_to_integrations
  wait_all_requests
  page.find(:css,'.md-locked-open').hover
  wait_all_requests
  click_link('Integrations')
  wait(3)
  wait_all_requests
end

def enable_google_sso
  wait_all_requests
  page.find('[aria-label="google_sso"]').trigger('click')
  wait_all_requests
  expect(page).to have_text('Google Enabled')
end

def disable_google_sso
  wait_all_requests
  page.find('[aria-label="google_sso"]').trigger('click')
  wait_all_requests
  expect(page).to have_text('Google Disabled')
end

def fill_fake_credentials_okta
  page.find('.okta_toggle md-switch').trigger('click')
  expect(page).to have_text('Identity Provider SSO url')
  expect(page).to have_text('Identity Provider Certificate')
  fill_in :identity_provider_sso_url_required, with: 'https://prime.shr-eng.com'
  fill_in :saml_certificate, with: '23112321312'
  wait_all_requests
  click_button 'Save'
  wait_all_requests
end

def fill_fake_credentials_one_login
  page.find('.one_login_toggle md-switch').trigger('click')
  expect(page).to have_text('Identity Provider SSO url')
  expect(page).to have_text('Identity Provider Certificate')
  fill_in :identity_provider_sso_url, with: 'https://prime.shr-eng.com'
  fill_in :saml_certificate, with: '23112321312'
  wait_all_requests
  click_button 'Save'
end

def fill_fake_credentials_adfs
  page.find('.adfs_toggle md-switch').trigger('click')
  expect(page).to have_text('Identity Provider SSO url')
  expect(page).to have_text('Identity Provider Certificate')
  fill_in :identity_provider_sso_url, with: 'https://prime.shr-eng.com'
  fill_in :saml_certificate, with: '23112321312'
  wait_all_requests
  click_button 'Save'
  wait_all_requests
end

def save_okta_credentials
  fill_fake_credentials_okta
end

def save_one_login_credentials
  fill_fake_credentials_one_login
end

def save_adfs_credentials
  fill_fake_credentials_adfs
end

def enable_okta_sso
  save_okta_credentials
end

def disable_okta_sso
  page.find('[aria-label="okta"]').trigger('click')
  expect(page).to have_text('Would you like to disable this integration?')
  expect(page).to have_text('Are you sure you want to disable this integration? Disabling this integration will clear setup details.')
  click_button 'Yes'
  wait_all_requests
  expect(page).to have_text('Okta Credentials Removed')
end

def enable_one_login_sso
  save_one_login_credentials
end

def disable_one_login_sso
  page.find('[aria-label="one_login"]').trigger('click')
  expect(page).to have_text('Would you like to disable this integration?')
  expect(page).to have_text('Are you sure you want to disable this integration? Disabling this integration will clear setup details.')
  click_button 'Yes'
  wait_all_requests
  expect(page).to have_text('One Login Credentials Removed')
end

def enable_adfs_sso
  save_adfs_credentials
end

def navigate_to_sso
  wait_all_requests
  find('.border-line-item', :text => I18n.t('admin.company_section_menu.sso')).trigger('click')
  wait_all_requests
  expect(page).to have_text('SSO Management')
  expect(page).to have_text('Confirm how team members should access the Sapling platform')
  expect(page).to have_link("Learn More", :href => "https://kallidus.zendesk.com/hc/en-us/articles/360018226497-Sapling-Platform-Settings#sso")
end

def select_paasword_and_sso
  choose_item_from_dropdown("sso_options", "Password and SSO")
  wait_all_requests
  click_button 'SAVE'
  expect(page).to have_text('Authentication Settings Saved')
end

def select_sso_only
  choose_item_from_dropdown("sso_options", "SSO Only")
  wait_all_requests
  expect(page).to have_text("New hires will have to use their company email to log into Sapling from their first day.")
  wait_all_requests
  click_button 'SAVE'
  expect(page).to have_text('Authentication Settings Saved')
end

def sign_out
  wait_all_requests
  find('#user-menu .icon-chevron-down').click
  wait_all_requests
  click_button(I18n.t('admin.header.menu.sign_out'))
  wait_all_requests
  expect(page).to have_text('Welcome Back')
end

def check_login_page_for_password_and_google_sso
  wait_all_requests
  expect(page).to have_text('Welcome Back')
  expect(page).to have_text('SIGN IN WITH GOOGLE')
  expect(page).to have_text('Sign in with email')
  page.find('.sign-in-with-email').trigger('click')
  expect(page).to have_link("Forgot Password?", :href => "#/forget_password")
end

def check_login_page_for_google_sso_only
  check_login_page_for_password_and_google_sso
  start_date_past_user_credentials
  sso_only_text
  check_login_page_for_password_and_google_sso
  start_date_today_user_credentials
  sso_only_text
  check_login_page_for_password_and_google_sso
  start_date_future_user_credentials
  wait_all_requests
  expect(page).to have_css(".username")
end

def check_login_page_for_password_and_okta_sso
  wait_all_requests
  expect(page).to have_text('Welcome Back')
  expect(page).to have_text('Sign in with Okta')
  expect(page).to have_text('Sign in with email')
  page.find('.sign-in-with-email').trigger('click')
  expect(page).to have_link("Forgot Password?", :href => "#/forget_password")
end

def check_login_page_for_okta_sso_only
  check_login_page_for_password_and_okta_sso
  start_date_past_user_credentials
  sso_only_text
  check_login_page_for_password_and_okta_sso
  start_date_today_user_credentials
  sso_only_text
  check_login_page_for_password_and_okta_sso
  start_date_future_user_credentials
  wait_all_requests
  expect(page).to have_css(".username")
end

def check_login_page_for_password_and_one_login_sso
  wait_all_requests
  expect(page).to have_text('Welcome Back')
  expect(page).to have_text('Sign in with One Login')
  expect(page).to have_text('Sign in with email')
  page.find('.sign-in-with-email').trigger('click')
  expect(page).to have_link("Forgot Password?", :href => "#/forget_password")
end

def check_login_page_for_one_login_only
  check_login_page_for_password_and_one_login_sso
  start_date_past_user_credentials
  sso_only_text
  check_login_page_for_password_and_one_login_sso
  start_date_today_user_credentials
  sso_only_text
  check_login_page_for_password_and_one_login_sso
  start_date_future_user_credentials
  wait_all_requests
  expect(page).to have_css(".username")
end

def check_login_page_for_password_and_adfs_sso
  wait_all_requests
  expect(page).to have_text('Welcome Back')
  expect(page).to have_text('Sign in through KPMG network')
  expect(page).to have_text('Sign in with email')
  page.find('.sign-in-with-email').trigger('click')
  expect(page).to have_link("Forgot Password?", :href => "#/forget_password")
end

def check_login_page_for_adfs_sso_only
  check_login_page_for_password_and_adfs_sso
  start_date_past_user_credentials
  sso_only_text
  check_login_page_for_password_and_adfs_sso
  start_date_today_user_credentials
  sso_only_text
  check_login_page_for_password_and_adfs_sso
  start_date_future_user_credentials
  wait_all_requests
  expect(page).to have_css(".username")
end

def start_date_today_user_credentials
  fill_in :email, with: sarah.email
  fill_in :password, with: sarah.password
  click_on t('log_in.submit')
  wait_all_requests
end

def start_date_past_user_credentials
  fill_in :email, with: hilda.email
  fill_in :password, with: hilda.password
  click_on t('log_in.submit')
  wait_all_requests
end

def start_date_future_user_credentials
  wait_all_requests
  fill_in :email, with: user.email
  fill_in :password, with: user.password
  click_on t('log_in.submit')
  wait_all_requests
end

def sso_only_text
  expect(page).to have_text('Oops!')
  expect(page).to have_text('Email login has been disabled by IT. Contact someone at your office for your company email address.')
  page.find('[md-font-icon="icon-arrow-left"]').trigger('click')
  wait_all_requests
end


def user_signed_in_successfully
  start_date_future_user_credentials
  expect(page).to have_css(".username")
end

def check_email_format
  fill_in :email, with: 'asd'
  fill_in :password, with: 'password'
  wait_all_requests
  expect(page).to have_text('Email has wrong format')
end

def check_logged_in_after_multiple_failed_attempts
  fill_in :email, with: user.email
  fill_in :password, with: 'wrongpass'
  click_on t('log_in.submit')
  wait_all_requests
  expect(page).to have_text('The email or password you entered is invalid.')

  wait_all_requests
  fill_in :email, with: user.email
  fill_in :password, with: 'wrongpass'
  click_on t('log_in.submit')
  wait_all_requests
  expect(page).to have_text('The email or password you entered is invalid.')

  wait_all_requests
  wait 3
  user_signed_in_successfully
end

def check_inactive_user
  fill_in :email, with: inactive_user.email
  fill_in :password, with: inactive_user.password
  click_on t('log_in.submit')
  wait_all_requests
  expect(page).to have_text("The email or password you entered is invalid")
  expect(page).not_to have_css(".username")
end

def check_sso_management_after_disabling_google_sso_integration
  naviagete_to_integrations
  disable_google_sso
  navigate_to_platform
  navigate_to_sso
  expect(page).to have_text('Password Only')
  expect(page).not_to have_text('Password and SSO')
  expect(page).not_to have_text('SSO Only')
end

def check_login_page_for_password_only
  wait_all_requests
  expect(page).to have_text('Welcome Back')
  expect(page).not_to have_text('Sign in with')
  check_email_format
  check_inactive_user
  check_logged_in_after_multiple_failed_attempts
end

def check_sso_management_after_disabling_okta_sso_integration
  naviagete_to_integrations
  disable_okta_sso
  navigate_to_platform
  navigate_to_sso
  expect(page).to have_text('Password Only')
  expect(page).not_to have_text('Password and SSO')
  expect(page).not_to have_text('SSO Only')
end

def check_sso_management_after_disabling_one_login_sso_integration
  naviagete_to_integrations
  disable_one_login_sso
  navigate_to_platform
  navigate_to_sso
  expect(page).to have_text('Password Only')
  expect(page).not_to have_text('Password and SSO')
  expect(page).not_to have_text('SSO Only')
end
