require 'rails_helper'
RSpec.describe PeriodicJobs::Documents::RemoveExpiredUploadedFiles, type: :job do
  it 'should enque RemoveExpiredUploadedFiles job in sidekiq' do
  	files_upload_job_size = Sidekiq::Queues["default"].size
  	PeriodicJobs::Documents::RemoveExpiredUploadedFiles.new.perform
    expect(Sidekiq::Queues["default"].size).to eq(files_upload_job_size + 1)
  end
end