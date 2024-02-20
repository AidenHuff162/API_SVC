require 'feature_helper'

feature 'Work Flow', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:location) { create(:location, company: company) }

 background { Auth.sign_in_user sarah, sarah.password }

  describe " Step's to Add Work Flows " do
    background {
      wait_all_requests
    }

    #  scenario " Account owner can add Work Flow " do
    #   navigate_to_workflows
    #   add_new_workflow
    #   add_new_task
    #   update_task
    #   delete_task
    #   add_second_workflow
    #   add_newtask_in_secondworkflow
    #   update_workflow_name
    #   delete_workflow
    #   assign_workflow
    #   verify_task_details
    #   change_task_due_date
    #   count_overdue_tasks_before_task_completion
    #   count_complete_tasks_before_task_completion
    #   count_incomplete_tasks_before_task_completion
    #   complete_assign_tasks
    #   count_overdue_tasks_after_task_completion
    #   count_complete_tasks_after_task_completion
    #   count_incomplete_tasks_after_task_completion
    # end
  end
end
