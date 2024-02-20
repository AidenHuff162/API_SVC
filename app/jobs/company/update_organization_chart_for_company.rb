class Company::UpdateOrganizationChartForCompany
  include Sidekiq::Worker

  def perform
    Company.joins(:organization_chart).where(enabled_org_chart: true).try(:find_each) do |company|
      organization_chart = company.organization_chart
      if organization_chart.present? && organization_chart.updated_at.to_date <= 6.days.ago.to_date 
        company.run_create_organization_chart_job
      end
    end
  end
end
