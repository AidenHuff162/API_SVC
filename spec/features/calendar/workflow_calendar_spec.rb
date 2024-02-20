require 'feature_helper'

feature 'Tasks Test Case For Calendar', type: :feature, js: true do

given!(:company) { create(:company, subdomain: 'foo', enabled_calendar: true, enabled_time_off: true) }
given!(:location) { create(:location, company: company) }
given!(:team) { create(:team, company: company) }
given!(:sarah) { create(:sarah, company: company, preferred_name: "", location: location, team: team) }
given!(:tim) { create(:tim, company: company, manager: sarah) }

background { Auth.sign_in_user sarah, sarah.password }

	describe 'Add Tasks And Verify it on Calendar' do
	  # scenario 'Verify Calendar Functionality For Tasks'do
			# navigate_to_workflows
			# add_new_workflow
			# add_new_task_for_calendar
			# navigate_to_home
			# navigate_to_task_from_home
			# assigning_workflow
			# navigate_to_calendar
			# check_task_on_calendar
	  # end
	end
end
