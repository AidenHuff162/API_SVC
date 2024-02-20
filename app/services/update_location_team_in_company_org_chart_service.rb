class UpdateLocationTeamInCompanyOrgChartService

  attr_accessor :company, :user_ids

  def initialize(user_ids, company_id)
    @company = Company.find_by(id: company_id)
    @user_ids = user_ids
  end

  def update_organization_tree
    return if company.nil? || company.organization_chart.blank?
    organization_chart = company.organization_chart
    array_of_ids_check = organization_chart.user_ids
    org_chart = update_org_chart(organization_chart.chart, organization_chart.chart['children'])

    checked_users = company.users.where(id: array_of_ids_check)
    org_chart[:department_names] = checked_users.joins(:team).pluck(:name).uniq
    org_chart[:location_names] = checked_users.joins(:location).pluck(:name).uniq
    org_chart[:custom_group_names] = company.organization_chart.chart['custom_group_names']

    organization_chart.chart = org_chart
    organization_chart.save
  end

  def update_org_chart(parent, children)
    if user_ids.include?(parent['id'])
      user = User.find_by_id(parent['id'])
      parent[:location] = user.location.name if user.location
      parent[:department] = user.team.name if user.team
    end
    parent['children'].each_with_index do |child, ind|
      child = update_org_chart(child, child['children'])
      parent['children'][ind] = child
    end
    parent
  end
end