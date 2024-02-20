require 'rails_helper'

RSpec.describe PtoRequestService::RestOps::CreateRequest do
  let!(:company) {(create(:company, subdomain: "defs", enabled_calendar: true))}
  let!(:user) {create(:user_with_manager_and_policy, :auto_approval, :renewal_on_anniversary, company: company, start_date: company.time.to_date  + 1.days)}
  before do
    @pto_policy = user.pto_policies.first
    @pto_policy.update(expire_unused_carryover_balance: true)
    @pto_policy.update(carryover_amount_expiry_date: user.start_date + 1.days)
    user.update(start_date: user.start_date - 2.year)
    @date = company.time.to_date
    User.current = user
    stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
  end

  describe 'splitting request' do
    context 'should not split' do
      it 'should not split one day request' do
        params = {"begin_date" => @date + 1.day , "end_date"  => @date + 1.day, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false}
        PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform
        expect(user.pto_requests.count).to eq(1)
      end
    end

    context 'should split' do

      it 'should split if intercepting event is present' do
        params = {"begin_date" => @date  , "end_date"  => @date + 1.day, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false}
        PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform
        expect(user.pto_requests.count > 1).to eq(true)
      end

      it 'should split request overlapping two months' do
        params = {"begin_date" => @date.next_month.end_of_month  , "end_date"  => @date.next_month.end_of_month + 1.days, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false}
        PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform
        expect(user.pto_requests.count > 1).to eq(true)
      end

      it 'should split into mor than 2 if 2 intercepting events are present' do
        params = {"begin_date" => @date, "end_date"  => @date + 2.day, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false}
        PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform
        expect(user.pto_requests.count > 2).to eq(true)
      end

      # it 'should send one email ' do
      #   params = {"begin_date" => @date, "end_date"  => @date + 10.day, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false}
      #   expect{PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform}.to change{ CompanyEmail.all.count }.by(1)
      # end

      it 'should create one calendar event' do
        params = {"begin_date" => @date, "end_date"  => @date + 10.day, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false}
        expect{PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform}.to change{ CalendarEvent.all.count }.by(1)
      end

      it 'should have each request consisting own balance' do
        params = {"begin_date" => @date, "end_date"  => @date + 10.day, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false}
        PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform
        user.pto_requests.try(:each) do |pto|
          expect(pto.balance_hours).to eq(pto.get_balance_used)
        end
      end

      it 'should have all requests with same status' do
        params = {"begin_date" => @date, "end_date"  => @date + 10.day, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false}
        PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform
        expect(user.pto_requests.pluck(:status).uniq.count).to eq(1)
      end

      it 'should split if intercepting event is last renewal date' do
        params = {"begin_date" => @date - 369.days, "end_date"  => @date - 364.days, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false}
        PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform
        expect(user.pto_requests.count > 1).to eq(true)
      end

      it 'should create activities for main request and create comment' do
        params = {"begin_date" => @date , "end_date"  => @date + 10.days, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false, comments_attributes: [{"description"=>"s", "commenter_id"=> user.id}]}
        expect{ @pto = PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform}.to change{ Activity.all.count }.by(3)
        expect(@pto.comments.count).to eq(1)
      end



      context 'request for policy not allowing negative_balance' do
        before { @pto_policy.update(can_obtain_negative_balance: false)}
        it 'should not allow to make splitted requests if balance is not available' do
          params = {"begin_date" => @date, "end_date"  => @date + 10.day, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => (Pto::PtoEstimateBalance.new(user.assigned_pto_policies.first, @date + 10.day, user.company).perform[:estimated_balance]), "partial_day_included" => false}
          req = PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform
          expect(user.pto_requests.count).to eq(0)
        end
      end

      context 'edge cases' do
        it 'should allow to make request on intercepting event' do
          params = {"begin_date" =>  user.start_date, "end_date"  => user.start_date, "pto_policy_id" => @pto_policy.id, "user_id" => user.id, "balance_hours" => 8, "partial_day_included" => false}
          req = PtoRequestService::RestOps::CreateRequest.new(params, user.id).perform
          expect(user.pto_requests.count).to eq(1)
        end
      end

    end
  end
end
