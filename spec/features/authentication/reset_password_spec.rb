require 'feature_helper'

feature 'Reset Password', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Sarah can Reset Password' do
    scenario 'Reset Password From Settings' do
      change_user_password
    end
  end
end

def change_user_password
  clear_mail_queue
  page.find('.full-name').click
  wait_all_requests
  page.find('md-menu-item', :text => 'Settings').click
  wait_all_requests
  expect(page).to have_css('[name="password"]')
  fill_in :'password', with: 'Pass1234as$ad()'
  click_on ('RESET MY PASSWORD')
  wait_all_requests
  expect(page).to have_content("Your password has been updated. We've sent you an email confirming the change.")
  # Sidekiq::Testing.inline! do
  #   verify_reset_email
  # end
  click_on ('GO TO MY PROFILE')
  wait_all_requests
  page.find('md-tab-item', :text => 'Updates')
end

def verify_reset_email
  total_emails_trigger =  ActionMailer::Base.deliveries.count
  expect(total_emails_trigger).to eq(1)
  reset_email = ActionMailer::Base.deliveries.first
  expect(reset_email.subject).to eq('Your Sapling Password has been changed')
  expect(reset_email.body).to have_content('Your Sapling password has been changed. If you did not request this change, please contact our team at help@trysapling.com')
end
