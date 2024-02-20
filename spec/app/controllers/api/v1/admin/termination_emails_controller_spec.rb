# require 'rails_helper'

# RSpec.describe Api::V1::Admin::TerminationEmailsController, type: :controller do

#   let(:company) { create(:company) }
#   let(:user) { create(:user, state: :active, current_stage: :registered, company: company, role: 2 ) }

#   before do
#     allow(controller).to receive(:current_user).and_return(user)
#     allow(controller).to receive(:current_company).and_return(user.company)
#     @mailer_queue_size = Sidekiq::Queues["mailers"].size
#   end

#   describe "POST #create" do
#     it "should increase the number of queued sidekiq jobs by one" do
#       post :create, params: { user_id: user.id, description: "", subject: "", send_at: Time.now + 1.hour }
#       expect(response.status).to eq(200)
#       expect(TerminationEmail.find_by(user_id: user.id)).not_to eq(nil)
#       expect(Sidekiq::Queues["mailers"].size).to eq(@mailer_queue_size + 1)
#     end
#   end

# end
