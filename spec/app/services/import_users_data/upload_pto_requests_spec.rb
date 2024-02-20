require 'rails_helper'

RSpec.describe ImportUsersData::UploadPtoRequests do
  let!(:company) {create(:company)}
  let!(:current_user) { create(:user, state: :active, current_stage: :registered, role: :account_owner, company: company) }
  let(:user) {create(:user, company: company, start_date: Date.strptime('20-03-2022', '%d-%m-%Y'))}
  let(:policy) { create(:default_pto_policy, :policy_with_expiry_carryover, company: company, carryover_amount_expiry_date: company.time.to_date)}
  let!(:assigned_policy) { create(:assigned_pto_policy, pto_policy: policy, user: user, balance: 20, carryover_balance: 20)}
  let(:user_with_no_assigned_poicy) {create(:user, company: company, assigned_pto_policies: [], start_date: Date.strptime('20-03-2022', '%d-%m-%Y'))}
  let(:upload_date) { DateTime.now }

  #success requests
  let(:upload_pending_request) { {'Company Email': user.email, 'Begin date': '04/06/2022', 'End date': '04/06/2022', 'PTO policy': policy.id, 'Deduct balance': 0, 'Status': 'pending', 'Balance hours': 8 }.with_indifferent_access }
  let(:upload_approved_request) { {'Company Email': user.email, 'Begin date': '04/06/2022', 'End date': '04/07/2022', 'PTO policy': policy.id, 'Deduct balance': 1, 'Status': 'approved', 'Balance hours': 8 }.with_indifferent_access }
  let(:upload_cancelled_request) { {'Company Email': user.email, 'Begin date': '04/06/2022', 'End date': '04/07/2022', 'PTO policy': policy.id, 'Deduct balance': 1, 'Status': 'cancelled', 'Balance hours': 8 }.with_indifferent_access }
  let(:upload_denied_request) { {'Company Email': user.email, 'Begin date': '04/06/2022', 'End date': '04/07/2022', 'PTO policy': policy.id, 'Deduct balance': 1, 'Status': 'denied', 'Balance hours': 8 }.with_indifferent_access }
  let(:upload_partial_day_request) { {'Company Email': user.email, 'Begin date': '04/15/2022', 'End date': '04/15/2022', 'PTO policy': policy.id, 'Deduct balance': 0, 'Status': 'approved', 'Balance hours': 5}.with_indifferent_access }

  #failure requests
  let(:fail_email_request) { {'Company Email': '', 'Begin date': '04/04/2022', 'End date': '04/05/2022', 'PTO policy': policy.id, 'Deduct balance': 0, 'Status': 'pending'}.with_indifferent_access }
  let(:fail_begin_date_request) { {'Company Email': user.email, 'Begin date': '', 'End date': '04/05/2022', 'PTO policy': policy.id, 'Deduct balance': 0, 'Status': 'pending'}.with_indifferent_access }
  let(:fail_end_date_request) { {'Company Email': user.email, 'Begin date': '04/05/2022', 'End date': '', 'PTO policy': policy.id, 'Deduct balance': 0, 'Status': 'pending'}.with_indifferent_access }
  let(:fail_no_policy_request) { {'Company Email': user_with_no_assigned_poicy.email, 'Begin date': '04/13/2022', 'End date': '04/15/2022', 'PTO policy': policy.id, 'Deduct balance': 0, 'Status': 'pending'}.with_indifferent_access }
  let(:fail_no_status_request) { {'Company Email': user.email, 'Begin date': '04/05/2022', 'End date': '04/05/2022', 'PTO policy': policy.id, 'Deduct balance': 0, 'Status': nil}.with_indifferent_access }

  let(:data) { [upload_request_1, upload_request_2] }
  
  describe 'Create PTO Requests through flatfile' do
    context 'PTO requests should be created successfully' do
      it 'should create pending pto requests' do
        args = { company: company, data: [upload_pending_request], current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(user.pto_requests.where(status: 'pending').count).to eq(1)
      end

      it 'should create approved pto requests' do
        args = { company: company, data: [upload_approved_request], current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(user.pto_requests.where(status: 'approved').count).to eq(1)
      end

      it 'should create cancelled pto requests' do
        args = { company: company, data: [upload_cancelled_request], current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(user.pto_requests.where(status: 'cancelled').count).to eq(1)

      end

      it 'should create denied pto requests' do
        args = { company: company, data: [upload_denied_request], current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(user.pto_requests.where(status: 'denied').count).to eq(1)
      end

      it 'should create partial day pto requests' do
        args = { company: company, data: [upload_partial_day_request], current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(user.pto_requests.where(begin_date: '2022-04-15', end_date: '2022-04-15', balance_hours: 4).count).to eq(1)
      end

      it 'should send feedback email' do
        message_delivery = instance_double(ActionMailer::MessageDelivery)
        expect(UserMailer).to receive(:upload_user_feedback_email).and_return(message_delivery)
        allow(message_delivery).to receive(:deliver_now!).and_return(true)
        args = { company: company, data: [upload_pending_request], current_user: current_user, upload_date: DateTime.now }
        response = ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(response).to eq(true)
      end
    end

    context 'PTO Requests should not created if data is not correct' do

      it 'should not create if user email not present' do
        args = { company: company, data: [fail_email_request], current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(user.pto_requests.count).to eq(0)
      end

      it 'should not create if begin date not present' do
        args = { company: company, data: [fail_email_request], current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(user.pto_requests.count).to eq(0)
      end

      it 'should not create if end date not present' do
        args = { company: company, data: [fail_end_date_request], current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(user.pto_requests.count).to eq(0)
      end

      it 'should not create if assigned policy not present' do
        args = { company: company, data: [fail_no_policy_request], current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(user.pto_requests.count).to eq(0)
      end

      it 'should not create if status not present' do
        args = { company: company, data: [fail_no_status_request], current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadPtoRequests.new(args).perform
        expect(user.pto_requests.count).to eq(0)
      end
    end
  end
end
