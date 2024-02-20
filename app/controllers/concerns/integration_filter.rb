module IntegrationFilter
  extend ActiveSupport::Concern

  def send_to_integration?(user, company)
    flag = true
    if(company.integration_type == 'paylocity' || company.integration_type == 'adp_wfn_us' || company.integration_type == 'adp_wfn_can'|| company.integration_type == 'adp_wfn_us_and_can')
      filters = company.integrations.where(api_name: ["adp_wfn_us", "adp_wfn_can", "adp_wfn_us_and_can", "paylocity"]).pluck(:meta).first
      flag = false if filters['location_id'] && !filters['location_id'].first.blank? && !filters['location_id'].include?("all") && filters['location_id'].exclude?(user.location_id)
      flag = false if filters['team_id'] && !filters['team_id'].first.blank? && !filters['team_id'].include?("all") && filters['team_id'].exclude?(user.team_id)
      flag = false if filters['employee_type'] && !filters['employee_type'].first.blank? && !filters['employee_type'].include?("all") && filters['employee_type'].exclude?(user.get_custom_field_value_text("Employment Status"))
    end
    flag
  end
end
