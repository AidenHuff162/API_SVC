require 'feature_helper'

feature 'Onboard New User', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "Sarah") }
  given!(:location) { create(:location, company: company) }
  given!(:manager) { create(:user, company: company, preferred_name: "") }
  given!(:buddy) { create(:user, company: company, preferred_name: "") }
  given(:user_attributes) { attributes_for(:user) }
  given!(:team) { create(:team, company: company) }
  given!(:document) { create(:document, company: company) }
  given!(:workstream) { create(:workstream, company: company, name: 'workstream1') }
  given!(:task_owner) { create(:user, company: company) }
  given!(:task1) { create(:task, workstream: workstream, owner_id: sarah.id, name: 'Task1') }
  given!(:task2) { create(:task, workstream: workstream, owner_id: sarah.id, name: 'Task2') }
  given!(:task3) { create(:task, workstream: workstream, task_type: 'hire', name: 'Task3') }
  given!(:task4) { create(:task, workstream: workstream, task_type: 'manager', name: 'Task4') }
  given!(:task5) { create(:task, workstream: workstream, task_type: 'buddy', name: 'Task5') }
  given!(:welcome) { create(:welcome, company: company) }
  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

   describe 'Verify Onboarding Flow' do
    scenario 'delete default email durig onboarding' do
      navigate_to_onboard
      create_user_profile
      add_user_employee_record
      submit_activities
      find('.icon-delete').click
      wait(5)
      expect(page.all('tbody tr').count).to eq(0)
      initiate_onboarding
    end

    scenario 'onboarding flow with new and default email' do
      navigate_to_onboard
      create_user_profile
      add_user_employee_record
      submit_activities
      # create_schedule_email
      initiate_onboarding
    end
  end
end
