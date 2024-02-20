require 'rails_helper'

RSpec.describe Company::UpdateOrganizationChartForCompany, type: :job do
  

  it 'should update chart' do
    Sidekiq::Testing.inline! do
      company = FactoryGirl.create(:company, enabled_org_chart: true) 
      user = FactoryGirl.create(:user, company: company) 
      company.update(organization_root: user)
      allow_any_instance_of(Company).to receive(:run_create_organization_chart_job) {"Chart created"}
      company.organization_chart.update_column(:updated_at, 8.days.ago)
      updated_at = company.organization_chart.updated_at
      Company::UpdateOrganizationChartForCompany.new.perform
      expect(company.organization_chart.reload.updated_at).to_not eq(updated_at)
    end
  end

end