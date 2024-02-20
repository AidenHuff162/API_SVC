require 'feature_helper'

feature 'Active Tabs On Home Page', type: :feature, js: true do

given!(:company) { create(:company, subdomain: 'foo', enabled_calendar: true, enabled_time_off: true, is_using_custom_table: true) }
given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
given!(:tim) { create(:tim, company: company) }

background { Auth.sign_in_user sarah, sarah.password }

	describe 'Shift from one active tab to an other' do
		scenario 'Verify Active Tabs functionality' do
			verify_active_tabs
		end
	end
end
