namespace :log do
  desc "Archive logs to S3"
  task archive: :environment do
    folder_path = '/home/deployer/www/sapling/shared/log'
    
    chunk_size = 4096
    buf = ""

    files = Dir.entries(folder_path).select { |x| x =~ /\A.+\.log/ }
    files.each do |file|
      content = ""
      file_path = folder_path + '/' + file
      if Rails.env.production? && ENV['DEFAULT_HOST'] != 'shr-uat.com'
        current_file = File.new(file_path)
        
        while buf = current_file.read(chunk_size)
          buf.tap { |buf| content << buf }
        end

        compressed_file = ActiveSupport::Gzip.compress(content)

        filename = file + '_' + DateTime.now.to_s
        key = ENV['DEFAULT_HOST']+ '/' + Socket.gethostname + '/' + Date.today.to_s + '/' + filename + '.gz'
        object = Aws::S3::Resource.new(access_key_id: ENV['AWS_ACCESS_KEY'], secret_access_key: ENV['AWS_SECRET_KEY'], region: ENV['AWS_BACKUP_REGION'], endpoint: ENV['S3_ENDPOINT']).bucket(ENV['AWS_BACKUP_BUCKET']).object(key)
        object.put(body: compressed_file, acl: 'bucket-owner-full-control')
      end
      File.truncate(file_path, 0)
    end
  end
end
