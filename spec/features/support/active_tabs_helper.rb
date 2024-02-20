def verify_active_tabs
	expect(page).to have_selector('.md-active', :text => 'Updates')
	wait_all_requests
	page.find('md-tab-item' ,:text => 'Profile').click
	wait(2)
	expect(page).to have_selector('.md-active', :text => 'Profile')
	page.find('md-tab-item' ,:text => 'Tasks').click
    wait(2)
	expect(page).to have_selector('.md-active', :text => 'Tasks')
	page.find('md-tab-item' ,:text => 'Documents').click
	wait(2)
	expect(page).to have_selector('.md-active', :text => 'Documents')
	page.find('md-tab-item' ,:text => 'Calendar').click
	wait(2)
	expect(page).to have_selector('.md-active', :text => 'Calendar')
	page.find('md-tab-item' ,:text => 'Time Off').click
	wait(2)
	expect(page).to have_selector('.md-active', :text => 'Time Off')
	page.find('md-tab-item' ,:text => 'Job Details').click
	wait(2)
	expect(page).to have_selector('.md-active', :text => 'Job Details')
end
