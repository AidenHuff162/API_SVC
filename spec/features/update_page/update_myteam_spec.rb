require 'feature_helper'
feature 'update page testcaes' , type: :feature, js: true do
  given!(:company) { create(:rocketship_company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:nick) { create(:nick, company: company, preferred_name: "", manager: sarah) }
  given!(:workstream1) { create(:workstream, company: company) }
  given!(:task_owner) { create(:user, company: company) }
  given!(:task1) { create(:task, workstream: workstream1, owner: task_owner) }
  given!(:task2) { create(:task, workstream: workstream1, owner: task_owner) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'update page and verify its functionality' do
    scenario 'Team Activities' do
        # reassign_tasks_to_hire
        # navigate_to_team_tab
        # assign_tasks_to_team_member
        # # validation_updates_page
        # view_all
    end
  end
end
