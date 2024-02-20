class HrisIntegrationsService::Bamboo::File < HrisIntegrationsService::Bamboo::Initializer
  attr_reader :user

  def initialize(user)
    super(user.company)
    @user = user
  end

  def upload(document, document_path, filename = nil, ext)
    return if !bamboo_api_initialized?

    data = {
      method: :post,
      url: "https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{user.bamboo_id}/files",
      user: "#{bamboo_api.api_key}",
      password: "x",
      document_request: document.to_json
    }

    begin
      tempfile = Tempfile.new([filename, ext])
      open(tempfile.path, "wb") do |file|
        file.write open(document_path, &:read)
      end

      category_name = "New Hire Documents"
      file_category_id = find_or_create_employee_category(category_name)
      url = "https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{user.bamboo_id}/files"

      if file_category_id
        data = {
          method: :post,
          url: "https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{user.bamboo_id}/files",
          user: "#{bamboo_api.api_key}",
          password: "x",
          document_request: document.to_json,
          payload: {
            multipart: true,
            category: file_category_id,
            fileName: filename,
            file: tempfile.path,
            document_path: document_path
          }
        }

        request = RestClient::Request.new(
          method: :post,
          url: url,
          user: "#{bamboo_api.api_key}",
          password: "x",
          payload: {
           multipart: true,
           category: file_category_id,
           fileName: filename,
           share: 'yes',
           file: File.new(tempfile.path)
        })
        response  = request.execute

        log("#{user.id}: Upload Document In Bamboo (#{user.bamboo_id}) - Success", {request: data}, {response: response}, 200)
      end
      tempfile.close
      tempfile.unlink
    rescue Exception => exception
      log("#{user.id}: Upload Document In Bamboo (#{user.bamboo_id}) - Failure", {request: data}, {response: exception.message}, 500)
    end
  end

  private

  def find_or_create_employee_category(new_category_name)
    category_id = find_employee_category(new_category_name)
    if category_id == nil
      create_employee_category(new_category_name)
      category_id = find_employee_category(new_category_name)
    end
    category_id
  end

  def create_employee_category(category_name)
    category_xml = "<employee><category>#{category_name}</category></employee>"
    url = "https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/files/categories/"
    HTTParty.post(url,
      body: category_xml, 
      headers: { content_type: "text/html" }, 
      basic_auth: { username: bamboo_api.api_key, password: 'x' }
      )
  end

  def find_employee_category(category_name)
    url = "https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{user.bamboo_id}/files/view"

    request = RestClient::Request.new({
      method: :get,
      url: url,
      user: "#{bamboo_api.api_key}",
      password: "x"
      })

    response = request.execute
    hashed_categories = Hash.from_xml(response.gsub("\n", ""))

    category_id = nil

    if(hashed_categories["employee"] && hashed_categories["employee"]["category"])
      hashed_categories["employee"]["category"].each do |cat|
        if cat["name"].downcase == category_name.downcase
          category_id = cat["id"]
        end
      end
    end
    category_id
  end

end
