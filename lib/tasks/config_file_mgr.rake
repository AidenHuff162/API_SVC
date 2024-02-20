namespace :config_file_mgr do

  # Fetch secret name and secret password from AWS secrets manager
  def get_secrets
    client = Aws::SecretsManager::Client.new(region: ENV['AWS_SECRET_REGION'])
    return {
      "user_name": client.get_secret_value(secret_id: ENV['AWS_SECRET_MANAGER_USERNAME_ID']).secret_string,
      "password": client.get_secret_value(secret_id: ENV['AWS_SECRET_MANAGER_PASSWORD_ID']).secret_string
      }
  end

  task :encrypt_file, [:source_file_path, :destination_file_path] => :environment do |t, args|
    all_values = YAML.load_file(File.open(args.source_file_path))

    file_path = args.destination_file_path
    encrypted_values = {}

    def write_data f, key, value      
      data = ("#{key}: '#{value}'\n")
      f.write(data)
    end

    File.open(file_path, "w+") do |f|
      all_values.each do |key, value|
        if key.include? "encrypted"
          value.each do |encrypt_key, encrypt_value|
            # Send request for encryption and store response in encrypt_value
            uri = URI.parse(ENV['ENCRYPT_ENDPOINT_URL'])
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            request = Net::HTTP::Post.new(uri.request_uri)
            # secret_keys = get_secrets()
            request.basic_auth(ENV['REMOTE_CONFIG_ACCESS_USERNAME'], ENV['REMOTE_CONFIG_ACCESS_PASSWORD'])
            request.content_type = "plain/text"
            request.body = encrypt_value
            response = http.request(request)
            already_encrypt_value = response.body
            encrypted_values[encrypt_key] = already_encrypt_value
          end
        elsif key.include? Rails.env
          value.each do |inner_key, inner_value|
            write_data(f, inner_key, inner_value)
          end
        elsif value.class == String
          write_data(f, key, value)
        end
      end

      f.write("encrypted:\n")
      encrypted_values.each do |key, value|
        data = ("  #{key}: '{cipher}#{value}'\n")
        f.write(data)
      end      
    end
  end

  task :encrypt_frontend_envs, [:source_file_path, :destination_file_path] => :environment do |t, args|

    all_values = JSON.parse(File.open(args.source_file_path))

    file_path = args.destination_file_path
    data_values = {}
    encrypted_values = {}
    algolia_values = {}

    def encrypt_value value
      # Send request for encryption and store response in encrypt_value
      uri = URI(ENV['ENCRYPT_ENDPOINT_URL'])
      uri.query = URI.encode_www_form(get_secrets())
      res = Net::HTTP.get_response(uri)
      return res.body
    end

    all_values.each do |key, value|
      if key.include? "encrypted"
        value.each do |encrypt_key, encrypt_value|
          if encrypt_key == 'algolia'
            encrypt_value.each do |algolia_key, algolia_value|
              algolia_values[algolia_key] = encrypt_value(algolia_value)
            end
          else
            encrypted_values[encrypt_key] = encrypt_value(encrypt_value)
          end
        end
      elsif key.include? 'algolia'
        value.each do |algolia_key, algolia_value|
          algolia_values[algolia_key] = algolia_value
        end
      else
        data_values[key] = value
      end
    end  

    data_values.merge!(encrypted: encrypted_values, algolia: algolia_values)

    File.open(file_path, "w+") do |f|
      f.write(data_values.to_json)
    end
  end

  task test_secret_manager: :environment do
    client = Aws::SecretsManager::Client.new(region: ENV['AWS_SECRET_REGION'])
    puts client.get_secret_value(secret_id: ENV['AWS_SECRET_MANAGER_USERNAME_ID']).secret_string
  end

end 