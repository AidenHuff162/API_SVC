class UpdateLocationTeamInCompanyOrgChartJob
  include Sidekiq::Worker
  sidekiq_options :queue => :generate_org_chart, :retry => false, :backtrace => true

  def perform(user_ids, company_id)
    UpdateLocationTeamInCompanyOrgChartService.new(user_ids, company_id).update_organization_tree
  end
end