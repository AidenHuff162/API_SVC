require 'feature_helper'

feature 'Offboard User', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:user) { create(:user, company: company, role: :account_owner, preferred_name: "") }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:tim) { create(:tim, company: company, preferred_name: "") }
  given!(:peter) { create(:peter, company: company, preferred_name: "", manager_id: tim.id) }
  given!(:location) { create(:location, company: company) }

  given!(:manager) { create(:user, company: company, preferred_name: "") }
  given!(:buddy) { create(:user, company: company, preferred_name: "") }
  given!(:team) { create(:team, company: company) }

  given(:user_attributes) { attributes_for(:user) }
  given(:profile_attributes) { attributes_for(:profile) }
  given!(:document) { create(:document, company: company) }

  given!(:workstream1) { create(:workstream, company: company) }
  given!(:workstream2) { create(:workstream, company: company) }
  given!(:task1) { create(:task, workstream: workstream1) }
  given!(:task2) { create(:task, workstream: workstream2) }
  given!(:tuc) { create(:task_user_connection, owner: tim, task: task1, user: tim)}
  given!(:template_task) { create(:task, workstream: workstream1, owner: tim) }
  given!(:email_template) { create(:email_template,company: company, email_type: :offboarding)}
  given!(:welcome) { create(:welcome, company: company) }

  given!(:united_states) { create(:united_states) }
  given!(:alabama) { create(:alabama, country: united_states) }

  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Steps to Offboard User' do

    scenario 'Offboard User' do
      navigate_to_offboard
      confirm_offboard_user
      skip_reassigining_step
      skip_exit_finish_offboard
    end

    # scenario 'Offboard User by assigning_workflows' do
    #   navigate_to_offboard
    #   confirm_offboard_user
    #   skip_reassigining_step
    #   assign_workflows
    #   skip_exit_finish_offboard_assign
    # end

    scenario 'Offboard User by Re_assign_roles' do

      navigate_to_offboard
      confirm_offboard_user
      reassign_team_member
      reassign_active_tasks
      reassign_template_tasks
      skip_reassigining_step
      # assign_workflows
      skip_exit_finish_offboard_assign
    end

    scenario 'Offboard user with schedule email' do
      navigate_to_offboard
      confirm_offboard_user
      skip_reassigining_step
      # assign_workflows
      find('button', text: "SAVE & CONTINUE").click
      wait(2)
      initiate_offboarding
    end
   end
end
