module LoggingService::LoggingConstants

  CSV_LOGGINGS_LIMIT = 10_000
  LOGGINGS_FETCH_LIMIT = 50

  FILE_STORAGE_PATH = if Rails.env.development? || Rails.env.test?
                        Rails.root.join('tmp')
                      else
                        File.join(Dir.home, 'www/sapling/shared/')
                      end

end