require 'feature_helper'

feature 'update page testcaes' , type: :feature, js: true do
  given!(:company) { create(:rocketship_company, subdomain: 'foo', enabled_time_off: true) }
  given!(:user) { create(:user, company: company, role: :account_owner, preferred_name: "") }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:nick){create(:user_with_manager_and_policy, company: company,  manager: sarah)}

  given(:user_attributes) { attributes_for(:user) }
  given(:profile_attributes) { attributes_for(:profile) }
  given!(:document) { create(:document, company: company) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  given!(:workstream) { create(:workstream, company: company, name: 'workstream1') }
  given!(:task1) { create(:task, workstream: workstream, task_type: 'hire', name: 'Task1') }
  given!(:task2) { create(:task, workstream: workstream, task_type: 'hire', name: 'Task2') }
  given!(:task3) { create(:task, workstream: workstream, task_type: 'hire', name: 'Task3') }
  given!(:task4) { create(:task, workstream: workstream, task_type: 'hire', name: 'Task4', deadline_in: -6) }
  given!(:task5) { create(:task, workstream: workstream, task_type: 'hire', name: 'Task5', deadline_in: -6) }

  given!(:pto_policy) {create(:default_pto_policy, unlimited_policy: true, company: company, manager_approval: true)}


  background { Auth.sign_in_user sarah, sarah.password }

  describe 'update page and verify its functionality' do
    scenario 'My Activities' do
      # navigate_to_documents
      # single_sign_document
      # navigate_to_document_tab
      # assign_document
      navigate_to_tasks_tab
      assign_workflow_for_myactivities
      #TODO need to update the time off request model by default submit buttion is not enabled with current date
      # request_pto
      navigate_to_updates
      expand_activities_panel
      activities_validation
      validate_myactivities_view
    end

  end
end