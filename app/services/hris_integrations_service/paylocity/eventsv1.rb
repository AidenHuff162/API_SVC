class HrisIntegrationsService::Paylocity::Eventsv1
  if Rails.env.production?
    BASE_URL = 'https://api.paylocity.com/api/v1'
  else
    BASE_URL = 'https://apisandbox.paylocity.com/api/v1'
  end

  def request_onboard(paylocity_company_id, options)
    post("/companies/#{paylocity_company_id}/onboarding/employees", options)
  end

  def update(options)
    post("/update-employee", options)
  end

  def fetch_user(paylocity_company_id, employee_id, options)
    get("/company/#{paylocity_company_id}/employee/#{employee_id}", options)
  end 

  private
  def post(event_url, options)
    HTTParty.post(BASE_URL + event_url, options)
  end

  def get(event_url, options)
    HTTParty.get(BASE_URL + event_url, options)
  end
end