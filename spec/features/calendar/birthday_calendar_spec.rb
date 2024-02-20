require 'feature_helper'

feature 'Birthday Test Case For Calendar', type: :feature, js: true do

given!(:company) { create(:company, subdomain: 'foo', enabled_calendar: true, enabled_time_off: true) }
given!(:location) { create(:location, company: company) }
given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
given!(:tim) { create(:tim, company: company) }

background { Auth.sign_in_user sarah, sarah.password }

	describe 'Add Birthday And Verify it on Calendar' do
		scenario 'Self Birthday Check On Calendar' do
			adding_birthday
			navigate_to_calendar
			check_birthdays_on_calendar
		end
	end
end
