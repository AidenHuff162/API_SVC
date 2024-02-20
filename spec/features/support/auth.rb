module Auth
  extend Capybara::DSL

  module_function

  def sign_in_user(user, password = 'secret123$')
    visit 'http://foo.frontend.me:8081/#/login'
    sleep(1)
    fill_in :email, with: user.email
    fill_in :password, with: password
    sleep(1)
    click_on I18n.t('login.log_in')
  end
end
