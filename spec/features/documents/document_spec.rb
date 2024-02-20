require 'feature_helper'

feature 'Create Document', type: :feature, js: true do
  given!(:company) { create(:company, subdomain: 'foo') }
  given!(:sarah) { create(:sarah, company: company, preferred_name: "") }
  given!(:location) { create(:location, company: company) }

  given!(:manager) { create(:user, company: company, preferred_name: "") }
  given!(:buddy) { create(:user, company: company, preferred_name: "") }
  given!(:team) { create(:team, company: company) }

  given(:user_attributes) { attributes_for(:user) }
  given(:profile_attributes) { attributes_for(:profile) }
  given!(:document) { create(:document, company: company) }


  background { Auth.sign_in_user sarah, sarah.password }

  describe 'Signatory Documents' do
    scenario 'Add documents on document page' do
      # navigate_to_documents
      # single_sign_document
      # manager_sign_document
      # co_sign_document
      # create_document_upload_request
      # create_combine_packets
      # create_seperate_packets
      # navigate_to_document_tab
      # assign_document
      # assign_upload_request
      # assign_combine_packet
      # assign_seprate_packet
    end
  end
end
