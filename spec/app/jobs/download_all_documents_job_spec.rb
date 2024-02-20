require 'rails_helper'

RSpec.describe DownloadAllDocumentsJob, type: :job do

  let(:company) { create(:company) }

  it "it should download company's all documents" do
    doc1 = create(:document, company_id: company.id)
    doc2 = create(:document, company_id: company.id)
    userA = create(:user, company: company)
    userB = create(:user, company: company)
    create(:paperwork_request, :request_skips_validate, user_id: userA.id, document_id: doc1.id, state: "signed")
    create(:paperwork_request, :request_skips_validate, user_id: userA.id, document_id: doc2.id, state: "signed")
    create(:paperwork_request, :request_skips_validate, user_id: userB.id, document_id: doc2.id, state: "signed")
    DownloadAllDocumentsJob.perform_now(nil, nil, nil, company.id, 'test@test.com')
    email = CompanyEmail.last
    file_name = email.content.to_s.split('http://')[1].split('.zip')[0].split(':3001')[1].gsub(/%20/, ' ') + ".zip"
    Zip::File.open("public"+file_name) do |zip|
      expect(zip.count).to eq(3)
    end
  end

end
