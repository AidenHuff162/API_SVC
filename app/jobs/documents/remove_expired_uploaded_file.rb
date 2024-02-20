module Documents
  class RemoveExpiredUploadedFile
    include Sidekiq::Worker

    def perform
      UploadedFile.expired.destroy_all
    end
  end
end
