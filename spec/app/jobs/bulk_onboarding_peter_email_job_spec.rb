require 'rails_helper'

RSpec.describe BulkOnboardingPeterEmailJob, type: :job do

	let!(:company) { create(:company) }
  let!(:user) { create(:user, company: company) }
	let!(:nick) { create(:user_with_location, company: company, manager: user) }

	it 'should send email' do
    Sidekiq::Testing.inline! do
  	  expect {BulkOnboardingPeterEmailJob.new.perform(JSON.parse({"#{user.id}": [nick.id]}.to_json))}.to change{company.company_emails.count}.by(1)
    end
  end
end