require 'rails_helper'

RSpec.describe Documents::RemoveExpiredUploadedFile, type: :job do 

  let(:uploaded_file){ create(:uploaded_file, type: 'UploadedFile::Attachment') }

  it 'should remove expired uploaded files' do
  	uploaded_file.update_column(:updated_at, 3.days.ago)
    Documents::RemoveExpiredUploadedFile.new.perform
    expect(UploadedFile.expired.count).to eq(0)
  end

  it 'should not remove other uploaded files' do
    Documents::RemoveExpiredUploadedFile.new.perform
    expect(UploadedFile.expired.count).to eq(0)
  end
end