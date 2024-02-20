require 'feature_helper'

feature 'Create New Workspace', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:peter) { create(:peter, company: company, preferred_name: "") }

  given!(:tim) { create(:tim, company: company, preferred_name: "") }
  given!(:workspace_image) { create(:workspace_image) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Account Owner Creates New Workspace' do
    scenario 'Account owner can creates new workspace and view it' do
      navigate_to_workspace('account_owner')
    end

    scenario 'Admin can creates new workspace and view it' do
      Auth.sign_in_user peter, peter.password
      navigate_to_workspace('admin')
    end

    scenario 'Employee can not create new workspace and view it' do
      Auth.sign_in_user tim, tim.password
      navigate_to_workspace('employee')
    end
  end
end
