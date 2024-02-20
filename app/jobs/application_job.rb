class ApplicationJob < ActiveJob::Base
    queue_as :default
    if Rails.env.development? || Rails.env.test?
        FILE_STORAGE_PATH = ("#{Rails.root}/tmp")
    else
        FILE_STORAGE_PATH = File.join(Dir.home, 'www/sapling/shared/')
    end
end
