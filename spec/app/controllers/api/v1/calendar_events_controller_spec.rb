require 'rails_helper'

RSpec.describe Api::V1::CalendarEventsController, type: :controller do
  let(:current_company) { create(:company_with_team_and_location, enabled_calendar: true, enabled_time_off: true) }
  let(:current_company2) { create(:company_with_team_and_location, subdomain: 'foos', enabled_calendar: true) }
  let(:current_user) { create(:user, state: :active, current_stage: :registered, company: current_company) }
  let(:current_user2) { create(:peter, state: :active, current_stage: :registered, company: current_company2) }
  let(:new_user2) { create(:user, company: current_company) }
  let!(:user_event1) {create(:calendar_event, event_start_date: Time.now, company: current_company, eventable_id: current_user.id, event_type: 4) }
  let!(:user_event2) {create(:calendar_event, event_start_date: Time.now, company: current_company, eventable_id: new_user2.id, event_type: 4) }
  let!(:user_event3) {create(:calendar_event, event_start_date: Time.now, company: current_company, eventable_id: new_user2.id, event_type: 3) }
  let!(:user_event4) {create(:calendar_event, event_start_date: Time.now, company: current_company, eventable_id: current_user.id, event_type: 1) }
  let!(:nick) {FactoryGirl.create(:user_with_manager_and_policy, :auto_approval, company: current_company, location: current_company.locations.first, team: current_company.teams.first, start_date: Date.today - 1.year)}
  before { User.current = nick}
  let!(:pto_request) {create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id, status: 1)}
  let!(:workstream) {create(:workstream, company: current_company)}
  let!(:task) {create(:task, task_type: :owner, owner: nick, workstream: workstream)}
  let!(:task_user_connection) {create(:task_user_connection, due_date: Time.now, user: nick, task: task, owner: current_user, state: 'in_progress')}

  before do
      allow(controller).to receive(:current_user).and_return(current_user)
      allow(controller).to receive(:current_company).and_return(current_user.company)
  end

  describe 'authorization' do
    context 'same company' do
      it 'should allow super admin to manager' do
        ability = Ability.new(current_user)
        assert ability.can?(:manage, user_event1)
      end

      it 'should allow employee to read' do
        ability = Ability.new(nick)
        assert ability.can?(:read, user_event1)
      end

      it 'should allow employee to get_milestones' do
        ability = Ability.new(nick)
        assert ability.can?(:get_milestones, user_event1)
      end

      it 'should allow employee to manage' do
        ability = Ability.new(nick)
        assert ability.cannot?(:manage, user_event1)
      end
    end

    context 'other company' do
      it 'should not allow other company user to manager' do
        ability = Ability.new(current_user2)
        assert ability.cannot?(:manage, user_event1)
      end
    end
  end

  describe "Get #get_milestones" do
    it "should get events for updates page" do
      result = get :get_milestones, format: :json
      expect(response).to have_http_status(200)

      response = JSON.parse result.body
      expect(response.length).to eq(4)
      [current_user.id, new_user2.id, nick.id].should include(response[0]["eventable"]["user"]["id"])
    end

    it "should not return birthday events when birthday permissions are off" do
      calendar_permissions = current_company.calendar_permissions
      calendar_permissions[:birthdays] = false
      current_company.update calendar_permissions: calendar_permissions

      get :get_milestones, format: :json
      expect(response).to have_http_status(200)

      json = JSON.parse response.body
      expect(json.count).to eq(4)
    end

    it "should get events for updates page" do
      FactoryGirl.create_list(:calendar_event, 1, {event_type: 3, eventable_id: current_user.id, eventable_type: 'User', company: current_company})
      result = get :get_milestones, format: :json

      expect(response).to have_http_status(200)
      response = JSON.parse result.body

      expect(response.length).to eq(5)
      [current_user.id, new_user2.id, nick.id].should include(response[0]["eventable"]["user"]["id"])
    end

    it "should not return birthday events when birthday permissions are off" do
      FactoryGirl.create_list(:calendar_event, 1, {event_type: 3, eventable_id: current_user.id, eventable_type: 'User', company: current_company})
      calendar_permissions = current_company.calendar_permissions
      calendar_permissions[:anniversary] = false
      current_company.update calendar_permissions: calendar_permissions

      get :get_milestones, format: :json
      expect(response).to have_http_status(200)

      json = JSON.parse response.body
      expect(json.count).to eq(2)
    end
  end

  describe "Get #index" do

    #TODO Dilshad will fix these test cases random failing based on different month.

    # it "should get all events " do
    #   result = get :index, params: { id: current_user.id }, format: :json
    #   expect(response).to have_http_status(200)

    #   response = JSON.parse result.body

    #   expect(response.length).to eq(7)
    # end

    # it "should not return birthday events when birthday permissions are off" do
    #   calendar_permissions = current_company.calendar_permissions
    #   calendar_permissions[:birthday] = false
    #   current_company.update calendar_permissions: calendar_permissions

    #   result = get :index, params: { id: current_user.id }, format: :json
    #   expect(response).to have_http_status(200)

    #   json = JSON.parse response.body
    #   expect(json.count).to eq(5)
    # end

    # it "should not return task events when they user do not have permissions" do
    #   current_user.update(user_role_id: current_company.user_roles.where(role_type: UserRole.role_types['employee']))

    #   result = get :index, params: { id: current_user.id }, format: :json
    #   expect(response).to have_http_status(200)

    #   json = JSON.parse response.body
    #   expect(json.count).to eq(7)
    # end

    context 'Admin on his own calendar' do
      before do
        current_user.update(user_role_id: current_user.company.user_roles.where(role_type: UserRole.role_types['admin']).take.id)
      end

      it 'should be able to view own calendar with view_only permission' do
        result = get :index, params: { id: current_user.id }, format: :json
        expect(response).to have_http_status(200)
      end

      it 'should be able to view own calendar with no_access permission' do
        current_user.user_role.permissions["own_platform_visibility"]["time_off"] = "no_access"
        current_user.save!
        result = get :index, params: { id: current_user.id }, format: :json
        expect(response).to have_http_status(200)
      end
    end
  end

  describe "Get #show" do
    it "should return team and location" do
      result = get :show, params: { id: user_event1.id }, format: :json
      expect(response).to have_http_status(200)
      response = JSON.parse result.body
      expect(response.include?('teams')).to eq(true)
      expect(response.include?('locations')).to eq(true)
    end

    it "should not return team and location for invalid  id" do
      result = get :show, params: { id: 400 }, format: :json
      expect(response).to have_http_status(404)
    end
  end

  describe "filters" do
    context 'locations filter' do
      it 'should return events for the user with that location' do
        result = get :index, params: { id: current_user.id, location_filters: [nick.location_id].to_json }, format: :json
        result =  JSON.parse(result.body)
        expect(result.count).to eq(3)
        expect(result.map {|a| a['id']}.include?(pto_request.calendar_event.id)).to eq(true)
        expect(result.map {|a| a['id']}.include?(task_user_connection.calendar_events.first.id)).to eq(true)
      end

      it 'should not return events if no user with location is present' do
        nick.update(location_id: nil)
        result = get :index, params: { id: current_user.id, location_filters: [current_company.locations.first.id].to_json }, format: :json
        result =  JSON.parse(result.body)
        expect(result.count).to eq(0)
      end

      context 'holiday' do
        let!(:holiday) {create(:holiday, begin_date: Time.now, end_date: Time.now, company: current_company)}
        it 'should return holiday event on locations filters selected' do
          result = get :index, params: { id: current_user.id, location_filters: [nick.location_id].to_json }, format: :json
          result =  JSON.parse(result.body)
          expect(result.map {|a| a['id']}.include?(holiday.calendar_event.id)).to eq(true)
        end

        it 'should return holiday event on locations filters  not selected' do
          result = get :index, params: { id: current_user.id }, format: :json
          result =  JSON.parse(result.body)
          expect(result.map {|a| a['id']}.include?(holiday.calendar_event.id)).to eq(true)
        end

        it 'should return holiday event if locations filters  include holiday loction' do
          holiday.update(location_permission_level: [nick.location_id.to_s])
          result = get :index, params: { id: current_user.id, location_filters: [nick.location_id].to_json }, format: :json
          result =  JSON.parse(result.body)
          expect(result.map {|a| a['id']}.include?(holiday.calendar_event.id)).to eq(true)
        end

        it 'should not return holiday event if locations filters do not include holiday loction' do
          holiday.update(location_permission_level: [nick.location_id.to_s])
          result = get :index, params: { id: current_user.id, location_filters: [current_company.locations.where.not(id: nick.location_id).first.id].to_json }, format: :json
          result =  JSON.parse(result.body)
          expect(result.map {|a| a['id']}.include?(holiday.calendar_event.id)).to eq(false)
        end
      end
    end

    context 'departments filter' do
      it 'should return events for the user with that department' do
        result = get :index, params: { id: current_user.id, department_filters: [nick.team_id].to_json }, format: :json
        result =  JSON.parse(result.body)
        expect(result.count).to eq(3)
        expect(result.map {|a| a['id']}.include?(pto_request.calendar_event.id)).to eq(true)
        expect(result.map {|a| a['id']}.include?(task_user_connection.calendar_events.first.id)).to eq(true)
      end

      it 'should not return events if no user with department is present' do
        nick.update(team_id: nil)
        result = get :index, params: { id: current_user.id, department_filters: [current_company.teams.first.id].to_json }, format: :json
        result =  JSON.parse(result.body)
        expect(result.count).to eq(0)
      end

      context 'holiday' do
        let!(:holiday) {create(:holiday, begin_date: Time.now, end_date: Time.now, company: current_company)}
        it 'should return holiday event on department filters selected' do
          result = get :index, params: { id: current_user.id, department_filters: [nick.team_id].to_json }, format: :json
          result =  JSON.parse(result.body)
          expect(result.map {|a| a['id']}.include?(holiday.calendar_event.id)).to eq(true)
        end

        it 'should return holiday event on department filters  not selected' do
          result = get :index, params: { id: current_user.id }, format: :json
          result =  JSON.parse(result.body)
          expect(result.map {|a| a['id']}.include?(holiday.calendar_event.id)).to eq(true)
        end

        it 'should return holiday event if department filters  include holiday department' do
          holiday.update(team_permission_level: [nick.team_id.to_s])
          result = get :index, params: { id: current_user.id, department_filters: [nick.team_id].to_json }, format: :json
          result =  JSON.parse(result.body)
          expect(result.map {|a| a['id']}.include?(holiday.calendar_event.id)).to eq(true)
        end

        it 'should not return holiday event if department filters do not include holiday department' do
          holiday.update(team_permission_level: [nick.team_id.to_s])
          result = get :index, params: { id: current_user.id, department_filters: [current_company.locations.where.not(id: nick.team_id).first.id].to_json }, format: :json
          result =  JSON.parse(result.body)
          expect(result.map {|a| a['id']}.include?(holiday.calendar_event.id)).to eq(false)
        end
      end
    end

    context 'Manager filter' do
      it 'should return events for the managed user' do
        nick.manager&.calendar_events.destroy_all
        result = get :index, params: { id: current_user.id, managers_filters: [nick.manager_id].to_json }, format: :json
        result =  JSON.parse(result.body)
        expect(result.count).to eq(3)
        expect(result.map {|a| a['id']}.include?(pto_request.calendar_event.id)).to eq(true)
        expect(result.map {|a| a['id']}.include?(task_user_connection.calendar_events.first.id)).to eq(true)
      end

      it 'should not return events if managed user are not present' do
        manager_id =  nick.manager_id
        nick.manager.calendar_events.destroy_all
        nick.update(manager_id: nil)
        result = get :index, params: { id: current_user.id, managers_filters: [manager_id].to_json }, format: :json
        result =  JSON.parse(result.body)
        expect(result.count).to eq(0)
      end
    end

    context 'Event Type filter' do
      it 'should return events of the selected type' do
        result = get :index, params: { id: current_user.id, event_type_filters: [CalendarEvent.event_types[pto_request.calendar_event.event_type]].to_json }, format: :json
        result =  JSON.parse(result.body)
        expect(result.count).to eq(1)
        expect(result.map {|a| a['id']}.include?(pto_request.calendar_event.id)).to eq(true)
        expect(result.map {|a| a['id']}.include?(task_user_connection.calendar_events.first.id)).to eq(false)
      end
    end

    context 'Custom Group filter' do
      let!(:custom_group) {create(:custom_group, company: current_company)}
      it 'should return events for the user with that custom group option' do
        selected_option = custom_group.custom_field_options.first.id
        FactoryGirl.create(:custom_field_value, user: nick, custom_field: custom_group, custom_field_option_id: selected_option)
        result = get :index, params: { id: current_user.id, custom_group_filters: [selected_option].to_json }, format: :json
        result =  JSON.parse(result.body)
        expect(result.count).to eq(3)
        expect(result.map {|a| a['id']}.include?(pto_request.calendar_event.id)).to eq(true)
        expect(result.map {|a| a['id']}.include?(task_user_connection.calendar_events.first.id)).to eq(true)
      end

      it 'should not return events if no user with with custom_group option is present' do
        selected_option = custom_group.custom_field_options.first.id
        FactoryGirl.create(:custom_field_value, user: nick, custom_field: custom_group, custom_field_option_id: selected_option)
        result = get :index, params: { id: current_user.id, custom_group_filters: [custom_group.custom_field_options.where.not(id: selected_option).first.id].to_json }, format: :json
        result =  JSON.parse(result.body)
        expect(result.count).to eq(0)
      end
    end
  end
end
