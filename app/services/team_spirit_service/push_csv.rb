class TeamSpiritService::PushCsv

  require 'azure/storage/file'

  attr_reader :filename, :integration, :company
  delegate :logging, to: :helper_service

  def initialize(filename, integration, company)
    @filename = filename
    @integration = integration
    @company = company
  end

  def perform
    uploading_states = ""
    share_name = integration.storage_account_name
    folder = nil
    begin
      client = Azure::Storage::File::FileService.create(
        storage_account_name: integration.storage_account_name,
        storage_access_key: integration.storage_access_key
      )
      uploading_states += "account accessed \n"

      # create share if not present
      shares = client.list_shares()
      if shares.map { |e| e.name }&.exclude?(share_name)
        client.create_share(share_name)
      end
      uploading_states += "share found/created \n"

      # create directory if not present
      if integration.storage_folder_path.present?
        directory_path = client.list_directories_and_files(share_name, integration.storage_folder_path) rescue nil
        uploading_states += "list directories and files \n"

        if directory_path.nil?
          directory = ''
          integration.storage_folder_path&.split('/')&.reject(&:empty?).try(:each) do |dir|
            directory = directory + '/' + dir

            begin
              response = client.create_directory(share_name, directory)
            rescue Exception => e
              next if e.message.include?("403")
            end
          end

          uploading_states += "created directories: #{directory} \n"
        end

        folder = integration.storage_folder_path
      end

      content = IO.binread(File.expand_path(filename))
      file = client.create_file(share_name, folder, filename, content.size)
      client.put_file_range(share_name, folder, file.name, 0, content.size - 1, content)

      uploading_states += "files uploaded \n"
      logging.create(@company, 'TeamSpirit', "Push CSV to Azure Blob Endpoint - Success", nil, nil, 200)
      return 1

    rescue Exception => e
      uploading_states += "file upload failure \n"
      logging.create(@company, 'TeamSpirit', "Push CSV to Azure Blob Endpoint - Failure", nil, { :error => e.to_s, uploading_states: uploading_states }.to_json, 500)
      return -1
    end
  end

  def helper_service
    TeamSpiritService::Helper.new
  end
end
