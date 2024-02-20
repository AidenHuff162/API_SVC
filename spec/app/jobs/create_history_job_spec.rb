require 'rails_helper'

RSpec.describe CreateHistoryJob, type: :job do 

	let(:company) { create(:company_with_history) }
	let(:user) { create(:user, company: company) }

	it "updates description_count of history with same description" do
		user.company.histories.last.update_column(:description, I18n.t("history_notifications.email.user_invited", full_name: user.full_name))
    response = CreateHistoryJob.perform_now(user)
    expect(user.company.histories.last.description_count).to be == 2
	end

	it "creates history with different description" do 
		expect { CreateHistoryJob.perform_now(user) }.to change(user.company.histories, :count).by(1)
	end	

	it "creates history if no history exists for the company" do 
		company = create(:company)
		user = create(:user, company: company)
		expect { CreateHistoryJob.perform_now(user) }.to change(user.company.histories, :count).by(1)
	end	

end