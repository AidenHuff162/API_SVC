require 'feature_helper'

feature 'User can sign in', type: :feature, js: true do
  given(:password) { ENV['TEST_PASSWORD'] }
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:user) { create(:user, company: company, password: password, current_stage: User.current_stages[:registered]) }
  given!(:inactive_user) { create(:user, company: company, password: password, state: 'inactive') }

  background do
    visit root_path
  end

  describe 'User is signed in successfully' do
    scenario 'User sees home page' do
      fill_in :email, with: user.email
      fill_in :password, with: password
      click_on t('log_in.submit')

      wait_all_requests
      expect(page).to have_css(".username")
    end
  end

  describe 'User logged in after multiple failed attempts' do
    scenario 'User sees home page' do
      fill_in :email, with: user.email
      fill_in :password, with: 'wrongpass'
      click_on t('log_in.submit')
      wait_all_requests
      expect(page).to have_text('Welcome Back 🎉 The email or password you entered is invalid')

      wait_all_requests
      fill_in :email, with: user.email
      fill_in :password, with: 'wrongpass'
      click_on t('log_in.submit')
      wait_all_requests
      expect(page).to have_text('Welcome Back 🎉 The email or password you entered is invalid.')

      wait_all_requests
      fill_in :email, with: user.email
      wait_all_requests
      fill_in :password, with: password
      wait_all_requests
      wait(2)
      click_on t('log_in.submit')
      wait(3)
      expect(page).to have_css(".username")
    end
  end

  describe 'User sees sign in errors' do

    scenario 'Email has wrong format' do
      fill_in :email, with: 'asd'
      fill_in :password, with: 'password'
      wait_all_requests

      expect(page).to have_text('Email has wrong format')
    end

    scenario 'Invalid login credentials' do
      fill_in :email, with: user.email
      fill_in :password, with: 'wrongpass'
      click_on t('log_in.submit')

      expect(page).to have_text('Welcome Back 🎉 The email or password you entered is invalid.')
    end

  end

  describe 'Inactive user' do
    scenario 'User cannot log in' do
      fill_in :email, with: inactive_user.email
      fill_in :password, with: inactive_user.password
      click_on t('log_in.submit')

      wait_all_requests
      expect(page).to have_text("Welcome Back 🎉 The email or password you entered is invalid.")
      expect(page).not_to have_css(".username")
    end
  end

end