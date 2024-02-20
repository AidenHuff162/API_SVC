def navigate_to_reports
	navigate_to '/#/reports'
	wait_all_requests
end

def create_new_report
	click_on I18n.t ('admin.report.main.page_title')
	wait_all_requests
  	expect(page).to have_content I18n.t('admin.report.main.page_description')
   	page.find('md-tab-item', :text => I18n.t('admin.report.main.profile_info')).click
  	wait_all_requests
	click_on I18n.t('admin.report.main.create_new_report')
	wait_all_requests
	expect(page).to have_content I18n.t('admin.report.create_report.report_info')
	fill_in :name, with:'Test Report'
	click_on ('Next')
	wait_all_requests
end

def choose_fields
	count_fields_selected = page.all('.report-selected-field-wrap').count
	selected_field_count = page.find('#selected_field_count').text
	expect(selected_field_count).to eq('Fields Selected (10 selected)')
	page.find('.report-field-section-title',:text => 'Profile').click
	page.find('.report-field-wrap',:text => 'About').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	page.find('.report-field-section-title',:text => 'Profile').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	page.find('.report-field-section-title',:text => 'Personal Info').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	page.find('.report-field-wrap',:text => 'Preferred Name').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	page.find('.report-field-section-title',:text => 'Personal Info').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	page.find('.report-field-section-title',:text => 'Additional Info').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	page.find('.report-field-wrap',:text => 'Favorite Food').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	page.find('.report-field-section-title',:text => 'Additional Info').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	page.find('.report-field-section-title',:text => 'Private Info').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	page.find('.report-field-wrap',:text => 'Social Security Number').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	page.find('.report-field-section-title',:text => 'Private Info').click
	wait_all_requests
	expect(page).to have_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.report.create_report.field_added_to_selected'))
	wait_all_requests
	selected_field_count = page.find('#selected_field_count').text
	expect(selected_field_count).to eq('Fields Selected (14 selected)')
	click_on ('Next')
	wait_all_requests
end

def filter_sort
	page.find('#location .custom-multi-select').trigger('click')
	wait_all_requests
	find('md-select-menu md-content md-option div', text: 'Select All', match: :first).trigger('click')
	wait_all_requests
	find('md-select-menu md-content md-option div', text: location1.name, match: :first).trigger('click')
	wait_all_requests
	page.find('#employment_status .custom-multi-select').trigger('click')
	wait_all_requests
	find('md-select-menu md-content md-option div', text: 'Select All', match: :first).trigger('click')
	wait_all_requests
	find('md-select-menu md-content md-option div', text: 'Full Time', match: :first).trigger('click')
	wait_all_requests
	page.find('#department .custom-multi-select').trigger('click')
	wait_all_requests
	find('md-select-menu md-content md-option div', text: 'Select All', match: :first).trigger('click')
	wait_all_requests
	find('md-select-menu md-content md-option div', text: team1.name, match: :first).trigger('click')
	wait_all_requests
	find('[type="submit"]').trigger('click')
	wait_all_requests
	expect(page).to have_selector('#reports-table tr.odd td:nth-child(1)')
	reports_count =  page.all('#reports-table tr.odd td:nth-child(1)').count
	expect(reports_count).to eq(1)
end

def verify_reports_fields
	report_name = page.find('#reports-table tr.odd td:nth-child(1)').text
	expect(report_name).to eq('Test Report')
	login_username = page.find('.login_username').text
	report_owner = page.find('.break-word:nth-child(2) p[layout="row"]').text
	expect(report_owner).to include(login_username)
end

def edit_report
	page.find('#reports_action').click
	wait_all_requests
	page.find('.icon-pencil').trigger("click")
	wait_all_requests
	wait_for_element('[name="name"]')
	report_name = find('#report_name')
    report_name.send_keys('Update Test Report')
    click_on ('Next')
	wait_all_requests
	click_on ('Next')
	wait_all_requests
	find('[type="submit"]').trigger('click')
	wait_all_requests
	expect(page).to have_selector('#reports-table tr.odd td:nth-child(1)')
	reports_count =  page.all('#reports-table tr.odd td:nth-child(1)').count
	expect(reports_count).to eq(1)
end
