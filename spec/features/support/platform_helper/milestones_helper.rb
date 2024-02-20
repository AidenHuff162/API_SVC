def navigate_to_platform
  wait_all_requests
  page.find(:css,'.md-locked-open').hover
  wait_all_requests
  click_link('Platform')
  wait_all_requests
  expect(page).to have_text I18n.t('admin.platform.general.intro')
end

def change_date_format_to_usa
  choose_item_from_dropdown("date_format", "USA (mm/dd/yyyy)")
  wait_all_requests
end

def change_date_format_to_International
  choose_item_from_dropdown("date_format", "International (dd/mm/yyyy)")
  wait_all_requests
  click_button('SAVE')
  wait_all_requests
end
 
def change_date_format_to_ISO_8601
  choose_item_from_dropdown("date_format", "ISO 8601 (yyyy/mm/dd)")
  wait_all_requests
  click_button('SAVE')
  wait_all_requests
end

def change_date_format_to_Long_Date
  choose_item_from_dropdown("date_format", "Long Date (Dec 31, 2017)")
  wait_all_requests
  click_button('SAVE')
  wait_all_requests
end

def navigate_to_milestones
  wait_all_requests
  find('.border-line-item', :text => I18n.t('admin.company_section_menu.milestones')).trigger('click')
  wait_all_requests
  expect(page).to have_text I18n.t('admin.assets.milestones.intro')
  fill_in :value_name, with: 'Our history'
  wait_all_requests
end

def add_milestone date_format
  wait_all_requests
  find('.add-value-button', :text => I18n.t('admin.assets.milestones.add_new')).trigger('click')
  wait_all_requests
  expect(page).to have_text I18n.t('admin.general.assets.tell_us')
  fill_in :milestone_title, with: 'first milestone'
  milestone_date=(Date.today - 17.days).strftime(date_format)
  page.execute_script("$('.milestone_date .md-datepicker-input').val('#{milestone_date}').trigger('input')")
  wait_all_requests
  fill_in :milestone_description, with:'I am first'
  find('.actions button:nth-child(1)').click
  wait_all_requests
end

def check_milestone_edit_date_for_usa
  find('.actions button:nth-child(1)').click
  wait_all_requests
  milestone_edit_date=page.find('.milestone_date .md-datepicker-input').value
  expect(milestone_edit_date).to eq((Date.today - 17.days).strftime("%m/%d/%Y"))
  find('.actions button:nth-child(1)').click
end

def check_milestone_edit_date_for_International
  find('.actions button:nth-child(1)').click
  wait_all_requests
  milestone_edit_date=page.find('.milestone_date .md-datepicker-input').value
  expect(milestone_edit_date).to eq((Date.today - 17.days).strftime("%d/%m/%Y"))
  find('.actions button:nth-child(1)').click
end

def check_milestone_edit_date_for_ISO_8601
  find('.actions button:nth-child(1)').click
  wait_all_requests
  milestone_edit_date=page.find('.milestone_date .md-datepicker-input').value
  expect(milestone_edit_date).to eq((Date.today - 17.days).strftime("%Y/%m/%d"))
  find('.actions button:nth-child(1)').click
end

def check_milestone_edit_date_for_Long_Date
  find('.actions button:nth-child(1)').click
  wait_all_requests
  milestone_edit_date=page.find('.milestone_date .md-datepicker-input').value
  expect(milestone_edit_date).to eq((Date.today - 17.days).strftime("%b %d, %Y"))
  find('.actions button:nth-child(1)').click
end
