class HrisIntegrationsService::Bamboo::MetaList < HrisIntegrationsService::Bamboo::Initializer
  attr_reader :name_lists

  def initialize(company)
    super(company)
  end

  def fetch(name_lists = [])
    return unless bamboo_api_initialized?
    @name_lists = name_lists

    response = HTTParty.get("https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/meta/lists", 
      headers: { accept: "application/json" }, 
      basic_auth: { username: bamboo_api.api_key, password: 'x' }
      )

    select((JSON.parse(response.body) rescue nil))
  end

  def create(name_list, params, action)
    return unless bamboo_api_initialized?

    field_id = fetch(name_list).try(:first)['fieldId'] rescue nil

    begin
      response = HTTParty.put("https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/meta/lists/#{field_id}",
        body: params, 
        headers: { content_type: "text/html" }, 
        basic_auth: { username: bamboo_api.api_key, password: 'x' }
        )

      log("#{action} - Success", {request: params}, {response: response}, 200)
    rescue Exception => exception
      log("#{action} - Failure", {request: params}, {response: exception.message}, 500)
    end
  end

  private

  def name_existed?(meta_list)
    name_lists.select(&:present?).map(&:downcase).include? meta_list['name'].downcase
  end

  def select(meta_lists)
    return meta_lists if name_lists.blank? || meta_lists.blank?
    meta_lists.select(&:present?).select { |meta_list| name_existed?(meta_list) }
  end
end
