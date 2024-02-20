require 'rails_helper'

RSpec.describe CalendarEvent, type: :model do

  describe '#create' do
  	context 'sets color' do

  		it 'to #D745DF for training' do
  			event = FactoryGirl.create(:calendar_event, :pto_event, event_type: 12)
  			expect(event.color).to eq('#D745DF')
  		end

  		it 'to #542F9A for study' do
  			event = FactoryGirl.create(:calendar_event, :pto_event, event_type: 13)
  			expect(event.color).to eq('#542F9A')
  		end

  		it 'to #E7805D for work from home' do
  			event = FactoryGirl.create(:calendar_event, :pto_event, event_type: 14)
  			expect(event.color).to eq('#E7805D')
  		end

  		it 'to #C0606E for out of office' do
  			event = FactoryGirl.create(:calendar_event, :pto_event, event_type: 15)
  			expect(event.color).to eq('#C0606E')
  		end

  	end
	end

  describe 'helping methods' do
    let(:company) {create(:company, enabled_time_off: true, enabled_calendar: true)}
    let!(:nick) {FactoryGirl.create(:user_with_manager_and_policy, :auto_approval, company: company, start_date: Date.today - 1.year)}

    context 'pto events' do
      before { User.current = nick}
      let!(:pto_request) {create(:pto_request_skip_send_email_callback, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id, status: 1)}

      it 'should return pto events with range 0 to 15' do
        expect(CalendarEvent.fetch_pto_calendar_events(User.current, company.calendar_events, CalendarEvent.get_location_and_team_query([],[]), (0..15).to_a, [nick.id]).count).to eq(1)
      end

      it 'should return pto events with range 0 to 10' do
        expect(CalendarEvent.fetch_pto_calendar_events(User.current, company.calendar_events, CalendarEvent.get_location_and_team_query([],[]), (0..10).to_a, [nick.id]).count).to eq(1)
      end

      it 'should not return pto events if no events present' do
        pto_request.destroy
        expect(CalendarEvent.fetch_pto_calendar_events(User.current, company.calendar_events, CalendarEvent.get_location_and_team_query([],[]), (0..15).to_a, [nick.id]).count).to eq(0)
      end
    end

    context 'task events' do
      let!(:user) {FactoryGirl.create(:user, company: company)}
      let!(:task) {create(:task, task_type: :owner, owner: nick)}
      let!(:task_user_connection) {create(:task_user_connection, due_date: Date.today + 10.days, user: user, task: task, owner: user, state: 'in_progress')}
      let!(:task_user_connection2) {create(:task_user_connection, due_date: Date.today + 10.days, user: nick, task: task, owner: nick.manager, state: 'in_progress')}

      it 'should return task events on own tab' do
        expect(CalendarEvent.task_calendar_events(user, user, company.calendar_events, 'view_only', 'view_only', []).count).to eq(1)
      end

      it 'should return task events on others tab as account owner' do
        expect(CalendarEvent.task_calendar_events(nick.manager, nick, company.calendar_events, 'view_only', 'view_only', []).count).to eq(1)
      end

      it 'should return task events on others tab as account user' do
        expect(CalendarEvent.task_calendar_events(nick.manager, user, company.calendar_events, 'view_only', 'view_only', []).count).to eq(1)
      end

      it 'should return task events on others tab as manager' do
        nick.manager.update!(user_role_id: company.user_roles.where(role_type: UserRole.role_types['manager']))
        expect(CalendarEvent.task_calendar_events(nick.manager, nick, company.calendar_events, 'view_only', 'view_only', []).count).to eq(1)
      end

      it 'should return task events on others tab as admin' do
        nick.manager.update!(user_role_id: company.user_roles.where(role_type: UserRole.role_types['admin']))
        expect(CalendarEvent.task_calendar_events(nick.manager, nick, company.calendar_events, 'view_only', 'view_only', [nick.id]).count).to eq(1)
      end
    end

    context 'calendar task events' do
      let!(:user) {FactoryGirl.create(:peter, :with_location_and_team, company: company)}
      let!(:task) {create(:task, task_type: :owner, owner: user)}
      let!(:task_user_connection) {create(:task_user_connection, due_date: Date.today + 10.days, user: user, task: task, owner: user, state: 'in_progress')}
      it 'should return calendar events' do
        result = CalendarEvent.fetch_calendar_events(user, user.id, [user.location_id], [user.team_id], Date.today - 10.days, Date.today + 20.days, company,[],nil,[])
        expect(result.count).to be > 0
      end
    end

    context 'set_event_visibility' do
      let!(:user) {FactoryGirl.create(:peter, :with_location_and_team, company: company)}
      let!(:task) {create(:task, task_type: :owner, owner: user)}
      let!(:task_user_connection) {create(:task_user_connection, due_date: Date.today + 10.days, user: user, task: task, owner: user, state: 'in_progress')}
      it 'should set event visibility' do
        calender_event = CalendarEvent.last
        calender_event.set_event_visibility
        expect(calender_event.event_type).to eq("unavailable")
      end

      it 'should not set event visibility' do
        calender_event = CalendarEvent.last
        expect(calender_event.event_type).to eq("task_due_date")
      end
    end

    context 'year' do
      it 'should not return year if event_type is not anniversary' do
        calender_event = FactoryGirl.create(:calendar_event, :pto_event, event_type: 12)
        res = calender_event.year
        expect(res).to eq(nil)
      end
    end
  end

end
