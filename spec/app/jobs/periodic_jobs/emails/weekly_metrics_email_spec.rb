require 'rails_helper'
RSpec.describe PeriodicJobs::Emails::WeeklyMetricsEmail, type: :job do

	let(:company) { create(:company) }
  let!(:custom_email_alert_weekly_metrics) { create(:custom_email_alert_weekly_metrics, company: company) }
	
  it 'should enque WeeklyMetricsEmail job in sidekiq' do
  	adp_job_size = Sidekiq::Queues["weekly_metrics"].size
  	PeriodicJobs::Emails::WeeklyMetricsEmail.new.perform
  	company.reload
    expect(company.metrics_email_job_id.present?).to eq(true)
  end
end