def navigate_to_employee_record_tab
  page.find('md-tab-item', :text => I18n.t('onboard.home.toolbar.profile')).click
  wait(2) 
  wait_all_requests   
  page.all('.section-right-approval-icons .icon-pencil').each do |el|
    el.trigger('click')
  end
end

def employee_personal_information
  wait(2)
  fill_in :first_name, with: user_attributes[:first_name]
  fill_in :last_name, with: user_attributes[:last_name]
  fill_in :personal_email, with: user_attributes[:personal_email]

  scroll_to page.find('[name="mobile_phone_number"]', visible: false)
  wait_all_requests
  fill_in :home_phone_number,     with: '03009876543'

  fill_in :mobile_phone_number,   with: '03001234567'
  wait_all_requests

  page.execute_script("$[button:contains('Save'):enabled].click()")
  wait_all_requests
end
