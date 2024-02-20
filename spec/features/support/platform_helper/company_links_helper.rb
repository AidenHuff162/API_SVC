def navigate_to_platform
  wait_all_requests
  page.find(:css,'.md-locked-open').hover
  wait_all_requests
  click_link('Platform')
  wait_all_requests
  expect(page).to have_text I18n.t('admin.platform.general.intro')
end

def click_on_company_links
  wait_all_requests
  find('.border-line-item', text: 'Company Links').trigger('click')
  wait_all_requests
  expect(page).to have_text('A directory of helpful links for your team members. You can specifiy visibility by Location, Department or Employment Status.')
end

def add_company_links
  $i = 1
  while $i < 4  do
  wait_all_requests
  find('.button-add-links').click
  wait_all_requests
  fill_in :name, with:"companylink #{$i}"
  fill_in :url, with:'https://www.kallidus.com'
  find('.actions .sapling-primary').click
  wait_all_requests
  $i +=1
end
end

def verify_company_links
  wait_all_requests
  page.find('expansion-panel[title="Company Links"] .collapsed-div').trigger('click')
  wait_all_requests
  expect(page).to have_link("companylink 1", :href => "https://www.kallidus.com")
  expect(page).to have_link("companylink 2", :href => "https://www.kallidus.com")
  expect(page).to have_link("companylink 3", :href => "https://www.kallidus.com")
end

def update_company_links
  wait_all_requests
  total_links = page.all('.form-container .as-sortable-item .icon-dots-vertical').count
  expect(total_links).to eq(3)
  $i=1
  while $i <= total_links do
  find(".form-container .as-sortable-item:nth-child(#{$i}) .icon-dots-vertical").click
  wait(1)
  find('md-menu-content md-menu-item:nth-child(1) button').click
  wait_all_requests
  fill_in :name, with:"companylink_update #{$i}"
  fill_in :url, with:'http://www.saplinghr.com'
  find('.actions button:nth-child(2)').click
  wait_all_requests
  expect(page).to have_content("companylink_update #{$i}")
  $i +=1
end
end

def delete_company_links
  wait_all_requests
  total_links = page.all('.form-container .as-sortable-item .icon-dots-vertical').count
  expect(total_links).to eq(3)
  $i=1
  while $i <= total_links do
  find('.form-container .as-sortable-item:nth-child(1) .icon-dots-vertical').click
  wait(3)
  find('md-menu-content md-menu-item:nth-child(2) .md-primary').click
  wait_all_requests
  expect(page).to have_text I18n.t('admin.platform.company_links.confirmation_title')
  find('.md-confirm-button').click
  wait_all_requests
  expect(page).to have_no_content("companylink #{$i}")
  $i +=1
end
end
