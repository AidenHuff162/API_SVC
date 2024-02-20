require 'rails_helper'
RSpec.describe TimeOff::UpdatePtoRequestsBalanceByUser, type: :job do
  describe 'update pto balance' do
    let(:company) {create(:company, enabled_time_off: true)}
    let!(:nick) {FactoryGirl.create(:user_with_manager_and_policy, company: company, start_date: Date.today - 1.year)}
    before {User.current = nick}
    let!(:pto_request) { create(:default_pto_request, begin_date: company.time.to_date + 10.days, end_date: company.time.to_date + 10.days, user_id: nick.id, balance_hours: 8,pto_policy_id: nick.pto_policies.first.id) }
    
    
    context 'after create' do
      it 'should update pto balance' do
        Sidekiq::Testing.inline! do
          holiday = FactoryGirl.create(:holiday, begin_date: pto_request.begin_date, end_date: pto_request.begin_date, multiple_dates: false, company: company)
          expect(pto_request.reload.balance_hours).to eq(0)
        end
      end

      it 'should not update pto balance' do
        Sidekiq::Testing.inline! do
          holiday = FactoryGirl.create(:holiday, begin_date: pto_request.begin_date + 1.day, end_date: pto_request.begin_date + 1.day, multiple_dates: false, company: company )
          expect(pto_request.reload.balance_hours).to eq(8)
        end
      end
    end

    context 'after update' do
      let(:holiday) {FactoryGirl.create(:holiday, begin_date: pto_request.begin_date + 1.day, end_date: pto_request.begin_date + 1.day, multiple_dates: false, company: company )}
      it 'should update pto balance' do
        Sidekiq::Testing.inline! do
          holiday.update(begin_date: pto_request.begin_date, end_date: pto_request.begin_date)
          expect(pto_request.reload.balance_hours).to eq(0)
        end
      end

      it 'should not update pto balance' do
        Sidekiq::Testing.inline! do
          holiday.update(begin_date: pto_request.begin_date + 2.days, end_date: pto_request.begin_date + 2.days)
          expect(pto_request.reload.balance_hours).to eq(8)
        end
      end
    end

    context 'after destroy' do
      let!(:pto_request2) { create(:default_pto_request, begin_date: company.time.next_week.beginning_of_week, end_date: company.time.next_week.beginning_of_week, user_id: nick.id, balance_hours: 0,pto_policy_id: nick.pto_policies.first.id) }
      let(:holiday) {FactoryGirl.create(:holiday, begin_date: pto_request2.begin_date, end_date: pto_request2.begin_date, multiple_dates: false, company: company )}
      it 'should update pto balance' do
        Sidekiq::Testing.inline! do
          holiday.destroy
          expect(pto_request2.reload.balance_hours).to eq(8)
        end
      end
    end

    context 'multiple dates' do
      let!(:pto_request2) { create(:default_pto_request, begin_date: company.time.next_week.beginning_of_week, end_date: company.time.next_week.beginning_of_week + 1.day, user_id: nick.id, balance_hours: 16,pto_policy_id: nick.pto_policies.first.id) }
      it 'should update pto balance' do
        Sidekiq::Testing.inline! do
          FactoryGirl.create(:holiday, begin_date: pto_request2.begin_date, end_date: pto_request2.end_date, multiple_dates: true, company: company )
          expect(pto_request2.reload.balance_hours).to eq(0)
        end
      end
    end
  end
end