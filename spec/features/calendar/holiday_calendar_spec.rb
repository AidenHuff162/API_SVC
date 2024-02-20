require 'feature_helper'

feature 'Holidays Test Case For Calendar', type: :feature, js: true do

given!(:company) { create(:company, subdomain: 'foo', enabled_calendar: true, enabled_time_off: true) }
given!(:location) { create(:location, company: company) }
given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
given!(:tim) { create(:tim, company: company) }

background { Auth.sign_in_user sarah, sarah.password }

	describe 'Add Holidays And Verify it on Calendar' do
		scenario 'Verify Calendar Functionality For Holidays of Single Date' do
			navigate_to_company_settings
			navigate_to_holidays_tab
			create_new_holiday_single_date(2,"Independence Day")
			create_new_holiday_single_date(3,"Get together")
			navigate_to_home
			navigate_to_calendar
      check_holidays_on_calendar
		end

    scenario 'Verify Calendar Functionality For Holidays of Multiple Dates'do
      navigate_to_company_settings
      navigate_to_holidays_tab
      create_holiday_multiple_date("Summer Holidays")
      navigate_to_home
      navigate_to_calendar
      check_holidays_on_calendar
    end
	end
end
