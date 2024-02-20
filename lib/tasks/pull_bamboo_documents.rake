# USAGE:
# be rake pull_bamboo_documents:pull_bamboo_documents[1,"apikey","subdomain",'id1 id2 id3']
namespace :pull_bamboo_documents do
  task :pull_bamboo_documents, [:company_id, :bamboo_api_key, :bamboo_subdomain, :user_ids]=> :environment do |t, args|
    company = Company.find(args.company_id)
    return unless company.present?
    super_user_id = company.users.find_by(super_user: true).try(:id)
    users = []
    unfound_users = []
    if args.user_ids.present?
      employee_ids = args.user_ids.split(" ")
      employee_ids.each do |employee_id|
        url = URI("https://api.bamboohr.com/api/gateway.php/#{args.bamboo_subdomain}/v1/employees/#{employee_id}/?fields=workEmail%2ChomeEmail")
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Get.new(url)
        request["accept"] = 'application/json'
        request["content-type"] = "application/json"
        request.basic_auth(args.bamboo_api_key, "")
        response = http.request(request)
        response = JSON.parse(response.read_body) rescue nil
        users.push response if response
        unless response
          unfound_users.push employee_id
        end
      end
      puts "--- Could not find Bamboo data for the following users ---"
      p unfound_users
      users.each do |user|
        employee_user = company.users.where("(email = ? AND email IS NOT NULL) OR (personal_email = ? AND personal_email IS NOT NULL)", user["workEmail"], user["homeEmail"]).try(:take)
        unless employee_user.present?
          puts "--- Could not find user with email #{user['workEmail']} #{user['homeEmail']} ---"
          next
        end
        url = URI("https://api.bamboohr.com/api/gateway.php/#{args.bamboo_subdomain}/v1/employees/#{user["id"]}/files/view/")
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Get.new(url)
        request["accept"] = 'application/json'
        request["content-type"] = "application/json"
        request.basic_auth(args.bamboo_api_key, "")
        response = http.request(request)
        categories = JSON.parse(response.read_body)["categories"] rescue nil
        next unless categories.present?
        categories.each do |category|
          files = category["files"]
          files.each do |file|
            url = URI("https://api.bamboohr.com/api/gateway.php/#{args.bamboo_subdomain}/v1/employees/#{user["id"]}/files/#{file["id"]}")
            http = Net::HTTP.new(url.host, url.port)
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            request = Net::HTTP::Get.new(url)
            request["accept"] = 'application/json'
            request["content-type"] = "application/json"
            request.basic_auth(args.bamboo_api_key, "")
            response = http.request(request)
            file_data = response.read_body rescue nil
            unless file_data.present?
              puts "--- Could not load file with id #{file['id']} for user with email #{employee_user.email} #{employee_user.personal_email} ---"
              next
            end
            begin
              File.open("tmp/#{file['originalFileName']}", "wb") do |tempfile|
                tempfile.write(file_data)
                uploaded_file = UploadedFile::PersonalDocumentFile.create(entity_type: 'User',
                                    file: tempfile,
                                    type: "UploadedFile::PersonalDocumentFile",
                                    company_id: company.id,
                                    original_filename: file['originalFileName'],
                                    entity_id: employee_user.id,
                                    skip_scanning: true
                                   )
                PersonalDocument.create(user_id: employee_user.id, title: file['name'], attached_file: uploaded_file, description: "", created_by_id: super_user_id)
                puts "--- Uploaded document for user #{employee_user.id} #{employee_user.email} ---"
              end
              File.delete("tmp/#{file['originalFileName']}")
            rescue
              puts "-- Invalid file type --"
            end
          end
        end
      end
    end
  end
end
