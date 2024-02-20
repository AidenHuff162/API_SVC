require 'feature_helper'

feature 'Onboard New User', type: :feature, js: true do
  given!(:company) { create(:rocketship_company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "Sarah") }
  given!(:tim) { create(:tim, company: company, preferred_name: "") }
  given!(:taylor) { create(:taylor, company: company, preferred_name: "") }
  given!(:agatha) { create(:agatha, company: company, preferred_name: "") }
  given!(:hilda) { create(:hilda, company: company, preferred_name: "") }
  given!(:zebediah) { create(:zebediah, company: company, preferred_name: "") }
  given(:user_attributes) { attributes_for(:user) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'update page and verify Platform Experience working fine' do

    scenario 'Platform experience' do
      platform_experience
     end


  end
end
