require 'rails_helper'

RSpec.describe DownloadProfilePicturesJob, type: :job do
  let(:company) { create(:company) }

  describe 'should exit job without send downloading profile pictures email' do
    it 'should not send email if company is missing' do
      DownloadProfilePicturesJob.perform_now(nil, 'test@test.com')
      email = CompanyEmail.last

      expect(email).to be_nil
    end

    it 'should not send email if user is missing' do
      DownloadProfilePicturesJob.perform_now(company.id, nil)
      email = CompanyEmail.last

      expect(email).to be_nil
    end
  end

  describe 'should send downloading profile pictures email' do
    it "it should send email to company's all profile pictures" do
      nick = create(:nick, company: company)
      user = create(:user, company: company)

      DownloadProfilePicturesJob.perform_now(company.id, 'test@test.com')
      email = CompanyEmail.last
      
      file_name = email.content.to_s.split('http://')[1].split('.zip')[0].split(':3001')[1].gsub(/%20/, ' ') + ".zip"
      Zip::File.open("public#{file_name}") do |zip|
        expect(zip.count).to eq(1)
      end
    end
  end
end