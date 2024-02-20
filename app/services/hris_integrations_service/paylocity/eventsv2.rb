class HrisIntegrationsService::Paylocity::Eventsv2
  if Rails.env.production?
    BASE_URL = 'https://api.paylocity.com/api/v2'
  else
    BASE_URL = 'https://apisandbox.paylocity.com/api/v2'
  end

  def request_onboard(paylocity_company_id, options)
    post("/weblinkstaging/companies/#{paylocity_company_id}/employees/newemployees", options)
  end

   def fetch_codes(company_code, options, field_name)
    get("/companies/#{company_code}/codes/#{field_name}",options)
  end

  private
  
  def post(event_url, options)
    HTTParty.post(BASE_URL + event_url, options)
  end

  def get(event_url, options)
    HTTParty.get(BASE_URL + event_url, options)
  end
end