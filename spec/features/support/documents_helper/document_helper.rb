def navigate_to_documents
  wait_all_requests
  page.find(:css,'.md-locked-open').hover
  wait_all_requests
  click_link('Documents')
  wait_all_requests
  expect(page).to have_content("Documents")
end

def single_sign_document
  wait_all_requests
  wait(2)
  click_on ('Add Document to Sign')
  wait_all_requests
  fill_in :title, with: 'document_name'
  wait_all_requests
  fill_in :description, with: "document_description"
  wait_all_requests
  attach_ng_file('document', Rails.root.join('spec/factories/uploads/documents/document.pdf'), controller: 'documents_dialog')
  wait_all_requests

  wait_for_element('[type="submit"]')
  wait_all_requests
  page.find('#signatory_document_prepare').trigger('click')
  hello_sign_steps_single_document

  wait_all_requests
  document_title =page.find('#signatory_document tr:nth-child(1) td:nth-child(1)').text
  expect(document_title).to eq('document_name')

  wait_all_requests
  description_document=page.find('#signatory_document tr:nth-child(1) td:nth-child(2)').text
  expect(description_document).to eq('document_description')

  wait_all_requests
  uname =page.find('.full-name').text
  document_created_by =page.find('#signatory_document tr:nth-child(1) td:nth-child(3) p:nth-child(1)').text
  expect(uname).to eq(document_created_by)

  wait_all_requests
  today_date = Date.today.strftime("%m/%d/%Y")

  document_created_date =page.find('#signatory_document tr:nth-child(1) td:nth-child(3) p:nth-child(2)').text
  expect(document_created_date).to eq(today_date)

  edit_single_sign_document
  downlaod_document
end

def edit_single_sign_document
  wait_all_requests
  page.find('#signatory_document tr:nth-child(1) td:nth-child(4) md-icon').trigger('click')
  page.find('.md-active  md-menu-item:nth-child(1) span').click()
  wait_all_requests
  fill_in :'title',  with:'Test Document'
  fill_in :'description',  with:'Please sign it'
  wait_all_requests
  click_on I18n.t('admin.documents.paperwork.update')
  wait(2)
  doc_name =page.find('#signatory_document tr:nth-child(1) td:nth-child(1)').text
  expect(doc_name).to eq('Test Document')

  wait_all_requests
  doc_desc=page.find('#signatory_document tr:nth-child(1) td:nth-child(2)').text
  expect(doc_desc).to eq('Please sign it')
end

def downlaod_document
  wait_all_requests
  page.find('#signatory_document tr:nth-child(1) td:nth-child(4) md-icon').trigger('click')
  wait(2)
  page.execute_script("window.getFile = function() { var xhr = new XMLHttpRequest();  xhr.open('GET', $('.md-active  md-menu-item:nth-child(2) a').attr('href'), false);  xhr.send(null); return xhr.responseText; }")
  click_on('Download')
  data = page.evaluate_script("getFile()")
  expect(data).not_to eq(:nil)
  expect(page).to have_no_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.documents.paperwork.error_message'))
end

def delete_single_sign_document
  wait_all_requests
  page.find('#signatory_document tr:nth-child(1) td:nth-child(4) md-icon').trigger('click')
  page.find('.md-active  md-menu-item:nth-child(3) span').click()
  wait_all_requests
  click_button('Yes')
  wait_all_requests
  expect(page).to have_content('No data available in table')
  page_reload
  wait_all_requests
  expect(page).to have_content('No data available in table')
end

def manager_sign_document
  click_on ('Add Document to Sign')
  wait_all_requests
  fill_in :'title', with: 'Manager sign Document'
  wait_all_requests
  fill_in :'description', with: 'Document for manager sign'
  wait_all_requests
  choose_item_from_dropdown('representative','Manager Co-Signs')
  attach_ng_file('document', Rails.root.join('spec/factories/uploads/documents/document.pdf'), controller: 'documents_dialog')
  wait_all_requests
  wait_for_element('[type="submit"]')
  click_on I18n.t('admin.documents.paperwork.prepare')
  wait_all_requests

  hello_sign_steps_manager_document
  wait_all_requests
  expect(page).to have_content("Manager sign Document")
  expect(page).to have_content("Document for manager sign")

  downlaod_document
end

def hello_sign_steps_manager_document
  wait(10)
  page.accept_alert
  wait(20)
  wait_for_element('img.doc_page_imgss')
  within_frame(find('#hsEmbeddedFrame')) do
    page.execute_script("$('#form_button_form_signature').click()")
    page.execute_script("$('img.doc_page_img')[0].click()")
    wait_all_requests
    page.execute_script("$('.wrapper.interactive p').click()")
    wait_all_requests
    page.execute_script("$('.assignment-select').val(2).change()")
    wait_all_requests
    page.execute_script("$('img.doc_page_img')[0].click()")
    page.execute_script("$('img.doc_page_img')[0].click()")
    wait(3)
    page.execute_script("$('.component-interact.pink .assignment-select').val(1).change()")
    wait_all_requests
    page.find('#saveButton button').trigger('click')
    wait_all_requests
    end
end

def downlaod_manager_sign_document
  wait_all_requests
  page.find('#signatory_document tr:nth-child(1) td:nth-child(4) md-icon').trigger('click')
  wait(2)
  page.execute_script("window.getFile = function() { var xhr = new XMLHttpRequest();  xhr.open('GET', $('.md-active  md-menu-item:nth-child(2) a').attr('href'), false);  xhr.send(null); return xhr.responseText; }")
  data = page.evaluate_script("getFile()")
  expect(data).not_to eq(:nil)
  expect(page).to have_no_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.documents.paperwork.error_message'))
end

def co_sign_document
  click_on ('Add Document to Sign')
  fill_in :'title',  with:'Co-Assign Document'
  fill_in :'description',  with:'Please sign cosign document'
  choose_item_from_dropdown('representative','Another Team Member Co-Signs')
  wait_all_requests
  choose_item_from_autocomplete("search_representative","#{sarah.first_name} #{sarah.last_name}")
  attach_ng_file('document', Rails.root.join('spec/factories/uploads/documents/document.pdf'), controller: 'documents_dialog')
  wait_all_requests
  wait_for_element('[type="submit"]')
  wait_all_requests
  click_on I18n.t('admin.documents.paperwork.prepare')
  hello_sign_steps_co_sign_document

  wait_all_requests
  expect(page).to have_content("Co-Assign Document")
  expect(page).to have_content("Please sign cosign document")

  downlaod_document
end

def create_document_upload_request
  wait_all_requests
  click_on ('Upload Requests')
  wait_all_requests
  click_on ('CREATE NEW UPLOAD REQUEST')
  wait_all_requests
  upload_request_name = 'Upload pic'
  upload_request_description= 'Upload Your Pic Please'

  fill_in :'title', with: upload_request_name
  fill_in :'description', with: upload_request_description
  wait_all_requests
  page.find('.admin_employee_records_dialog .sapling-primary').trigger('click')
  wait(1)

  wait_all_requests
  upload_doc_name = page.find('#upload_document tr:nth-child(1) td:nth-child(1)').text
  expect(upload_request_name).to eq(upload_doc_name)

  wait_all_requests
  upload_doc_description = page.find('#upload_document tr:nth-child(1) td:nth-child(2)').text
  expect(upload_doc_description).to eq(upload_request_description)
  wait_all_requests

  edit_upload_request_document
end

def edit_upload_request_document
  wait_all_requests
  wait(1)
  page.find('#upload_document tr:nth-child(1) td:nth-child(4) md-icon').trigger('click')
  page.find('.md-active  md-menu-item:nth-child(1) span').click()
  wait_all_requests
  fill_in :'title',  with:'Upload Document'
  fill_in :'description',  with:'Please Upload this document'
  wait_all_requests
  click_on I18n.t('admin.documents.paperwork.save')
  wait(1)

  upload_name = page.find('#upload_document tr:nth-child(1) td:nth-child(1)').text
  expect(upload_name).to eq('Upload Document')

  wait_all_requests
  upload_description = page.find('#upload_document tr:nth-child(1) td:nth-child(2)').text
  expect(upload_description).to eq('Please Upload this document')
end

def delete_upload_request_document
  wait_all_requests
  page.find('#upload_document tr:nth-child(1) td:nth-child(4) md-icon').trigger('click')
  page.find('.md-active  md-menu-item:nth-child(2) span').click()
  wait_all_requests
  click_button('Yes')
  wait_all_requests
  expect(page).to have_content('No data available in table')
  page_reload
  wait_all_requests
  expect(page).to have_content('No data available in table')
end


def create_seperate_packets
  click_on ('Document Packets')
  wait_all_requests
  click_on I18n.t('admin.documents.paperwork.add_document_to_packet')
  wait_all_requests
  fill_in :name, with:'Seperate Test Packet'
  fill_in :description, with:'Document Test Packet'
  choose_item_from_dropdown('packet_types','Keep documents Separate')
  wait_all_requests

  check_array = find_all('md-checkbox')
  check_array.each do |click_checkbox|
    click_checkbox.trigger("click")
  end
  wait_all_requests
  click_on 'Create Packet'
  wait_all_requests
  reload_page

  expect(page).to have_content('Seperate Test Packet')
  expect(page).to have_content('Document Test Packet')
end

def create_combine_packets
  click_on I18n.t('admin.documents.paperwork.add_document_to_packet')
  wait_all_requests
  fill_in :name, with:'Combine Test Packet'
  fill_in :description, with:'Document Test Packet'
  choose_item_from_dropdown('packet_types','Combine into one document')
  wait_all_requests

  check_array = find_all('md-checkbox')
  check_array.each do |click_checkbox|
    click_checkbox.trigger("click")
  end
  wait_all_requests
  click_on 'Create Packet'
  wait_all_requests

  reload_page

  expect(page).to have_content('Combine Test Packet')
  expect(page).to have_content('Document Test Packet')
end

def navigate_to_document_tab
  wait_all_requests
  navigate_to "/#/updates"
  wait_all_requests
  page.find('md-tab-item' ,:text => 'Documents').click
end

def assign_document
  wait_all_requests
  page.find('#assign_doc').trigger('click')
  click_on 'Request Signature'
  click_on 'Existing'
  wait_all_requests
  choose_item_from_dropdown('paperwork','Test Document')
  click_on 'Review Document'

  wait(10)
  page.accept_alert
  wait(20)

  within_frame(find('#hsEmbeddedFrame')) do
    wait_all_requests
    page.find('#saveButton button').trigger('click')
    wait_all_requests
  end
  wait_all_requests
  expect(page).to have_content('Test Document')
end

def assign_upload_request
  wait_all_requests
  page.find('#assign_doc').trigger('click')
  click_on 'Request File Upload'
  click_on 'Existing'
  wait_all_requests
  choose_item_from_dropdown('paperwork','Upload Document')
  click_on 'Review Document'
  wait_all_requests
  expect(page).to have_content('Upload Document')
end

def assign_combine_packet
  wait_all_requests
  page.find('#assign_doc').trigger('click')
  click_on 'Assign Packet'
  click_on 'Existing'
  wait_all_requests
  choose_item_from_dropdown('paperwork','Combine Test Packet')
  click_on 'Assign Packet'

  wait(10)
  page.accept_alert
  wait(20)

  within_frame(find('#hsEmbeddedFrame')) do
    wait_all_requests
    page.find('#saveButton button').trigger('click')
    wait_all_requests
  end

  wait_all_requests
  expect(page).to have_content('Combine Test Packet')
end


def assign_seprate_packet
  wait_all_requests
  page.find('#assign_doc').trigger('click')
  click_on 'Assign Packet'
  click_on 'Existing'
  wait_all_requests
  choose_item_from_dropdown('paperwork','Seperate Test Packet')
  click_on 'Assign Packet'
  wait(5)
  expect(page).to have_content('Seperate Test Packet')
end


# def check_download_all
#   wait_all_requests
#   click_on 'Download All'
#   wait(2)
#   page.execute_script("window.getFile = function() { var xhr = new XMLHttpRequest();  xhr.open('GET', $('.md-active  md-menu-item:nth-child(2) a').attr('href'), false);  xhr.send(null); return xhr.responseText; }")
#   data = page.evaluate_script("getFile()")
#   expect(data).not_to eq(:nil)
#   expect(page).to have_no_selector('.md-toast-content .md-toast-text', :text => I18n.t('admin.documents.paperwork.error_message'))
# end
