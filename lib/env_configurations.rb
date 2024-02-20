module EnvConfigurations

  def initialize_env_configurations
    begin
      bootstrap_values = (YAML::load_file('config/bootstrap.yml')).to_h
    rescue Exception => e
      if e.to_s.include? "No such file or directory"
        puts 'Bootstrap.yml file is missing.'
      elsif e.to_s.include? "undefined method"
        puts 'Invalid file format for bootstrap.yml'
      else
        puts 'Unable to load variables from bootstrap.yml'
      end
    end
    if bootstrap_values.present? && bootstrap_values.class.name == 'Hash'
      bootstrap_values.each do |key, value|
        ENV[key] = value if ENV[key].blank?
      end
    else
      ENV['FETCH_ENVS_FROM_REMOTE_URL'] = 'false'
    end
    if ENV['FETCH_ENVS_FROM_REMOTE_URL'] == 'true'
      set_values(fetch_config_variables('APP_CONFIG_URL'))
      ENV['GOOGLE_AUTH_CONFIG'] = fetch_config_variables('GOOGLE_AUTH_CONFIG_URL').to_json
      ENV['GOOGLE_SHEETS_CONFIG'] = fetch_config_variables('GOOGLE_SHEETS_CONFIG_URL').to_json
      ENV['HEALTH_CHECK_CONFIG'] = fetch_config_variables('CRONJOB_HEALTH_CHECK_CONFIG_URL').to_json

      firebase_admin_json = fetch_config_variables('FIREBASE_CONFIG_URL')
      ENV['FIREBASE_ADMIN_JSON'] = firebase_admin_json.to_json if firebase_admin_json.present? && firebase_admin_json.class.name == 'Hash'

      directory_name = File.join(Dir.home, ENV['ENV_LOCAL_STORAGE_PATH'] + "/config/.ssl.temp/")
			Dir.mkdir(directory_name) unless File.exists?(directory_name)

      xerox_data = fetch_config_variables('XERO_CERT_CONFIG_URL')
      create_cert_files(File.join(Dir.home, ENV['ENV_LOCAL_STORAGE_PATH'] + "/config/.ssl.temp", "xerox_key.pem"), xerox_data, "private_key") if xerox_data.present? && xerox_data.has_key?("private_key")
      adp_data = fetch_config_variables('ADP_CERT_CONFIG_URL')
      create_cert_files(File.join(Dir.home, ENV['ENV_LOCAL_STORAGE_PATH'] + "/config/.ssl.temp", "adpapiclient_certificate.pem"), adp_data, "public_cert") if adp_data.present? && adp_data.has_key?("public_cert")
      create_cert_files(File.join(Dir.home, ENV['ENV_LOCAL_STORAGE_PATH'] + "/config/.ssl.temp", "adpapiclient_private.key"), adp_data, "private_key") if adp_data.present? && adp_data.has_key?("private_key")
    end
    ENV['ENCRYPTION_KEY'] = ENV['ENCRYPTION_KEY']&.pack_encryption_key(16)
    ENV['ENCRYPTION_API_KEY'] = ENV['ENCRYPTION_API_KEY']&.pack_encryption_key(16)
    Rails.application.secrets.secret_key_base = Rails.application.secrets.secret_key_base&.pack_encryption_key(32)
  end

  def create_cert_files file_path, data, key
  	File.open(file_path, "w+") do |f|
  		f.write(data[key])
  	end
  end

  def set_values values
    values.each do |key, value|
      if value.class.name == 'Hash'
        value.each do |key, value|
          ENV[key] = value if ENV[key].blank?
        end
      elsif value.class.name == 'String'
        ENV[key] = value if ENV[key].blank?
      end
    end if values.present? && values.class.name == 'Hash'
  end

  def fetch_config_variables url_key
    begin
      if url_key.present? && ENV[url_key].include?(".json")
        uri = URI.parse(ENV[url_key])
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Get.new(uri.request_uri)
        request.basic_auth(ENV['REMOTE_CONFIG_ACCESS_USERNAME'], ENV['REMOTE_CONFIG_ACCESS_PASSWORD'])
        response = http.request(request)
        return JSON.parse(response.body)
      end
    rescue Exception => e
      if e.to_s.include? "Failed to open TCP connection"
        puts 'Failed to open TCP connection.'
      elsif e.to_s.include? "undefined method"
        puts 'Invalid format from config-svc request.'
      else
        puts 'Invalid response from config-svc request.'
      end
    end
  end
  module_function :fetch_config_variables
end 