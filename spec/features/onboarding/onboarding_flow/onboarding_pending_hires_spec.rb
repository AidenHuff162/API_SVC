require 'feature_helper'

feature 'Onboarding Flow', type: :feature, js: true do
  # given!(:company) { create(:company, subdomain: 'foo') }
  # given!(:sarah) { create(:sarah, company: company, preferred_name: "Sarah") }
  # given!(:location) { create(:location, company: company) }
  # given!(:manager) { create(:user, company: company, preferred_name: "") }
  # given!(:buddy) { create(:user, company: company, preferred_name: "") }
  # given(:user_attributes) { attributes_for(:user) }
  # given!(:team) { create(:team, company: company) }
  # given!(:document) { create(:document, company: company) }
  # given!(:workstream) { create(:workstream, company: company, name: 'workstream1') }
  # given!(:task_owner) { create(:user, company: company) }
  # given!(:task1) { create(:task, workstream: workstream, owner_id: sarah.id, name: 'Task1') }
  # given!(:task2) { create(:task, workstream: workstream, owner_id: sarah.id, name: 'Task2') }
  # given!(:task3) { create(:task, workstream: workstream, task_type: 'hire', name: 'Task3') }
  # given!(:task4) { create(:task, workstream: workstream, task_type: 'manager', name: 'Task4') }
  # given!(:task5) { create(:task, workstream: workstream, task_type: 'buddy', name: 'Task5') }
  # given!(:welcome) { create(:welcome, company: company) }
  # given!(:united_states) { create(:united_states) }
  # given!(:alabama) { create(:alabama, country: united_states) }
  # given!(:email_template) do
  #   create(:email_template,
  #     company: company,
  #     subject: "<p>Welcome <span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"First Name\">First Name</span>‌</p>",
  #     cc:  "<p>#{Faker::Internet.email}</p>",
  #     bcc: "<p>#{Faker::Internet.email}</p>",
  #     description: "<p>Hey!</p><p>Welcome to sapling.</p>"
  #     )
  #   end
  # given!(:welcome) do
  #     create(:welcome,
  #     company: company,
  #     subject: "<p>Welcome email for <span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"First Name\">First Name</span>‌<span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Last Name\">Last Name</span>‌</p>",
  #     cc:  "<p>#{Faker::Internet.email}</p>",
  #     bcc: "<p>#{Faker::Internet.email}</p>",
  #     description: "<p>Welcome to team Sapling.</p><p>Your manager is <span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Manager Full Name\">Manager Full Name</span>‌ &#97;&#110;&#100; buddy <span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Buddy Full Name\">Buddy Full Name</span>‌</p>",
  #     )
  #   end

  # background { Auth.sign_in_user sarah, sarah.password }

  scenario 'Verify Pending Hire Functionality' do
    # navigate_to_onboard
    # create_user_profile
    # pending_onboarding
    # onboard_pending_hires
    # add_user_employee_record
    # pending_hire_assign_activities
    # send_invite
  end
end
