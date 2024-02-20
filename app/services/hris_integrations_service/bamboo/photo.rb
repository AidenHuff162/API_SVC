class HrisIntegrationsService::Bamboo::Photo < HrisIntegrationsService::Bamboo::Initializer

  def initialize(company)
    super(company)
  end

  def fetch(bamboo_id)
    return if !bamboo_api_initialized?

    photo = HTTP.basic_auth(:user => bamboo_api.api_key, :pass => 'x')
      .headers(:content_type => "image/jpeg", :accept => "application/binary")
      .get("https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{bamboo_id}/photo/small")

    return if !photo.present? && !photo.body.present?

    tempfile = Tempfile.new(['image', '.jpeg'])
    tempfile.binmode
    tempfile.write photo.body
    tempfile.rewind
    tempfile.close
    tempfile.path
  end

  def create(user)
    return if !bamboo_api_initialized?

    data = { :method => :post, :url => "https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{user.bamboo_id}/photo",
          :user => "#{bamboo_api.api_key}", :password => "x" }

    begin
      if user.profile_image.present? && user.profile_image.file.present? && user.profile_image.file.url.present? && user.profile_image.file.url(:square_thumb).present?
        downloaded_image = MiniMagick::Image.open(user.profile_image.file.url(:square_thumb))

        require 'fileutils'
        unless File.directory?("#{Rails.root}/tmp/profile_image")
          FileUtils.mkdir_p("#{Rails.root}/tmp/profile_image")
        end

        request = RestClient::Request.new(
          :method => :post,
          :url => "https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{user.bamboo_id}/photo",
          :user => "#{bamboo_api.api_key}",
          :password => "x",
          :payload => {
           :multipart => true,
           :file => File.new("#{downloaded_image.path}", 'rb')
        })
        a_image = request.execute

        log("#{user.id}: Update Profile Photo In Bamboo (#{user.bamboo_id}) - Success", {request: data}, {response: a_image}, 200)
      end
    rescue Exception => e
      log("#{user.id}: Update Profile Photo In Bamboo (#{user.bamboo_id}) - Failure", {request: data}, {response: e.message}, 500)
    end
  end
end
