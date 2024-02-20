namespace :uploaded_files do
  desc 'Remove all expired uploaded files without entities'
  task remove_expired: :environment do
    UploadedFile.expired.destroy_all
  end
end
