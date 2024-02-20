require 'feature_helper'

feature 'transitions', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo', name: 'foo') }
  given!(:user) { create(:user, company: company, role: :account_owner, preferred_name: "") }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:tim) { create(:tim, company: company, preferred_name: "", current_stage: 'last_week') }
  given!(:peter) { create(:peter, company: company, preferred_name: "", current_stage: 'preboarding') }
  given!(:nick) { create(:nick, company: company, preferred_name: "", current_stage: 'registered', start_date: 6.years.ago, manager_id:sarah.id) }
  given!(:location) { create(:location, company: company) }

  given!(:manager) { create(:user, company: company, preferred_name: "") }
  given!(:buddy) { create(:user, company: company, preferred_name: "") }
  given!(:team) { create(:team, company: company) }

  given(:user_attributes) { attributes_for(:user) }
  given(:profile_attributes) { attributes_for(:profile) }
  given!(:document) { create(:document, company: company) }

  given!(:workstream1) { create(:workstream, company: company) }
  given!(:workstream2) { create(:workstream, company: company) }
  given!(:task3) { create(:task, workstream: workstream1, task_type: 'hire', name: 'Task3') }
  given!(:task4) { create(:task, workstream: workstream1, task_type: 'manager', name: 'Task4') }
  given!(:task5) { create(:task, workstream: workstream1, task_type: 'buddy', name: 'Task5') }

  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Steps to check transitions dashboard' do

     scenario 'Assign documents to onboarding user and check transition dashboard' do
      navigate_to_onboarding_user_documents
      assign_documents
      navigate_to_transition_dashboard
      search_onboarding_user_in_transition_dashboard
    end

    scenario 'Assign documents to offboarding user and check transition dashboard' do
      navigate_to_offboarding_user_documents
      assign_documents
      navigate_to_transition_dashboard
      search_offboarding_user_in_transition_dashboard
    end

    scenario 'Assign documents to active user and check transition dashboard' do
      navigate_to_active_user_documents
      assign_documents
      navigate_to_transition_dashboard
      search_active_user_in_transition_dashboard_and_verify_data_for_documents
    end
  end
end