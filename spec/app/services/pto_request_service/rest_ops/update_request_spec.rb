require 'rails_helper'

RSpec.describe PtoRequestService::RestOps::UpdateRequest do
  before(:each) do
    WebMock.disable_net_connect!
    @company = create(:company, subdomain: "defs", enabled_calendar: true)
    @user = create(:user_with_manager_and_policy, :auto_approval, :renewal_on_anniversary, :super_admin, company: @company, start_date: @company.time.to_date  + 1.days)
    @pto_policy = @user.pto_policies.first
    @pto_policy.update(expire_unused_carryover_balance: true)
    @pto_policy.update!(carryover_amount_expiry_date: @user.start_date + 1.days)
    @date = @company.time.to_date
    @user.update(start_date: @user.start_date - 2.year)
    User.current = @user
    params = {"begin_date" => @date, "end_date"  => @date + 10.day, "pto_policy_id" => @pto_policy.id, "user_id" => @user.id, "balance_hours" => 8, "partial_day_included" => false}
    @pto_request = PtoRequestService::RestOps::CreateRequest.new(params, @user.id).perform
    @pto_request.reload
  end


  describe 'splitting request' do
    context 'removing splitted requests' do
      it 'should remove splited requests on updating to one day' do
        params = {"id" => @pto_request.id, "end_date"  => @pto_request.begin_date, "balance_hours" => 8, "user_id" => @pto_request.user_id, "pto_policy_id" => @pto_request.pto_policy_id}
        PtoRequestService::RestOps::UpdateRequest.new(params, @pto_request, @user.id).perform
        expect(@pto_request.reload.partner_pto_requests.count).to eq(0)
      end

      it 'should remove splited requests on updating to partial request' do
        params = {"id" => @pto_request.id, "end_date"  => @pto_request.begin_date, "balance_hours" => 7, "partial_day_included" => true, "user_id" => @pto_request.user_id, "pto_policy_id" => @pto_request.pto_policy_id}
        PtoRequestService::RestOps::UpdateRequest.new(params, @pto_request, @user.id).perform
        expect(@pto_request.reload.partner_pto_requests.count).to eq(0)
      end
    end

    context 'should split' do

      it 'should split and remove the old request' do
        ppr_ids = @pto_request.partner_pto_requests.pluck(:id)
        params = {"id" => @pto_request.id, "end_date"  => @pto_request.begin_date + 2.day, "user_id" => @pto_request.user_id, "pto_policy_id" => @pto_request.pto_policy_id, "balance_hours" => 8, "partial_day_included" => false}
        PtoRequestService::RestOps::UpdateRequest.new(params, @pto_request, @user.id).perform
        expect(@pto_request.reload.partner_pto_requests.count > 1).to eq(true)
        expect(@pto_request.reload.partner_pto_requests.pluck(:id)).to_not eq(ppr_ids)
      end

      it 'should split it to two' do
        params = {"id" => @pto_request.id, "end_date"  => @pto_request.begin_date + 1.day, "user_id" => @pto_request.user_id, "pto_policy_id" => @pto_request.pto_policy_id, "balance_hours" => 8, "partial_day_included" => false}
        a = PtoRequestService::RestOps::UpdateRequest.new(params, @pto_request, @user.id).perform
        expect(@pto_request.reload.partner_pto_requests.count > 0).to eq(true)
      end

      it 'should send email on update ' do
        params = {"id" => @pto_request.id, "end_date"  => @pto_request.end_date + 1.day, "user_id" => @pto_request.user_id, "pto_policy_id" => @pto_request.pto_policy_id, "balance_hours" => 8, "partial_day_included" => false}
        expect{PtoRequestService::RestOps::UpdateRequest.new(params, @pto_request, @user.id).perform}.to change{ CompanyEmail.all.count }.by(1)
      end

      it 'should have one calendar event on update' do
        params = {"id" => @pto_request.id, "end_date"  => @pto_request.end_date + 1.day, "user_id" => @pto_request.user_id, "pto_policy_id" => @pto_request.pto_policy_id, "balance_hours" => 8, "partial_day_included" => false}
        expect{PtoRequestService::RestOps::UpdateRequest.new(params, @pto_request, @user.id).perform}.to change{ CalendarEvent.all.count }.by(0)
      end

      it 'should have each request consisting own balance on update' do
        params = {"id" => @pto_request.id, "end_date"  => @pto_request.end_date + 1.day, "user_id" => @pto_request.user_id, "pto_policy_id" => @pto_request.pto_policy_id, "balance_hours" => 8, "partial_day_included" => false}
        PtoRequestService::RestOps::UpdateRequest.new(params, @pto_request, @user.id).perform
        @user.reload.pto_requests.try(:each) do |pto|
          expect(pto.balance_hours).to eq(pto.get_balance_used)
        end
      end

      it 'should only add comment  and create activity' do
        params = {"id" => @pto_request.id, "end_date" => @pto_request.get_end_date, "user_id" => @pto_request.user_id, "pto_policy_id" => @pto_request.pto_policy_id, comments_attributes: [{"description"=>"s", "commenter_id"=> @user.id}], "balance_hours" => @pto_request.get_total_balance, "partial_day_included" => false}
        expect{PtoRequestService::RestOps::UpdateRequest.new(params, @pto_request, @user.id).perform}.to change{Activity.all.count}.by(1)
        expect(@pto_request.reload.comments.count).to eq(1)
      end

      it 'should update, add comment and create activities for both' do
        ppr_ids = @pto_request.partner_pto_requests.pluck(:id)
        params = {"id" => @pto_request.id, "end_date" => @pto_request.begin_date + 2.days, "user_id" => @pto_request.user_id, "pto_policy_id" => @pto_request.pto_policy_id, comments_attributes: [{"description"=>"s", "commenter_id"=> @user.id}], "balance_hours" => @pto_request.get_total_balance, "partial_day_included" => false}
        expect{PtoRequestService::RestOps::UpdateRequest.new(params, @pto_request, @user.id).perform}.to change{Activity.all.count}.by(2)
        expect(@pto_request.reload.comments.count).to eq(1)
        expect(@pto_request.reload.partner_pto_requests.count).to eq(2)
        expect(@pto_request.reload.partner_pto_requests.pluck(:id)).to_not eq(ppr_ids)
      end

    end
  end
end
