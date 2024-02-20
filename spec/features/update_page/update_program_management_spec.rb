require 'feature_helper'

feature 'update page testcaes' , type: :feature, js: true do
  given!(:company) { create(:rocketship_company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:tim) { create(:tim, company: company, preferred_name: "") }
  given!(:nick) { create(:nick, company: company, preferred_name: "") }
  given!(:taylor) { create(:taylor, company: company, preferred_name: "") }
  given!(:maria) { create(:maria, company: company, current_stage: :invited) }

  given(:user_attributes) { attributes_for(:user) }
  given(:profile_attributes) { attributes_for(:profile) }
  given!(:document) { create(:document, company: company) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }
  given!(:location) { create(:location, company: company) }
  given!(:team) { create(:team, company: company) }

  given!(:workstream1) { create(:workstream, company: company) }
  given!(:task1) { create(:task, workstream: workstream1, task_type: 'hire', name: 'Task1') }
  given!(:task2) { create(:task, workstream: workstream1, task_type: 'hire', name: 'Task2') }
  given!(:task3) { create(:task, workstream: workstream1, task_type: 'hire', name: 'Task3') }
  given!(:task4) { create(:task, workstream: workstream1, task_type: 'hire', name: 'Task4') }
  given!(:task5) { create(:task, workstream: workstream1, task_type: 'hire', name: 'Task5', deadline_in: -6) }
  given!(:task6) { create(:task, workstream: workstream1, task_type: 'hire', name: 'Task6', deadline_in: -6) }


  background { Auth.sign_in_user sarah, sarah.password }

  describe 'update page and verify its functionality' do
    scenario 'Program Management panel on updates page' do
      navigate_to_user_tasks
      assign_tasks_for_program_management
      navigate_to_other_user_tasks
      assign_tasks_for_program_management
      offboard_user_for_program_management
      navigate_to_updates
      expand_program_management_panel
      onboard_people_CTA
      navigate_to_updates
      expand_program_management_panel
      offboard_people_CTA
      navigate_to_updates
      expand_program_management_panel
      open_tasks_CTA
      navigate_to_updates
      expand_program_management_panel
      overdue_tasks_CTA
   end
  end
end
