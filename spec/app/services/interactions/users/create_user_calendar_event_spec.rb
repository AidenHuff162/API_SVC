require 'rails_helper'

RSpec.describe Interactions::Users::CreateUserCalendarEvent do

  let!(:company) {create(:company, enabled_calendar: true)}
  let!(:user) {create(:user, company: company)}
  

  describe 'calendater events' do
    context 'anniversary' do
      it 'should create an anniversary calendar event' do
        user.update(start_date: Date.today)
        expect{Interactions::Users::CreateUserCalendarEvent.new.perform}.to change{user.calendar_events.where(event_type: CalendarEvent.event_types["anniversary"]).all.count}.by(1)
      end

      it 'should not create an anniversary calendar event if start_date of future' do
        user.update(start_date: Date.today + 2.days)
        expect{Interactions::Users::CreateUserCalendarEvent.new.perform}.to change{user.calendar_events.where(event_type: CalendarEvent.event_types["anniversary"]).all.count}.by(0)
      end

      it 'should not create an anniversary calendar event if start_date of past' do
        user.update(start_date: Date.today + 2.days)
        expect{Interactions::Users::CreateUserCalendarEvent.new.perform}.to change{user.calendar_events.where(event_type: CalendarEvent.event_types["anniversary"]).all.count}.by(0)
      end

      it 'should not create an anniversary calendar event if no anniversary event' do
        user.update(start_date: Date.today)
        user.calendar_events.where(event_type: CalendarEvent.event_types["anniversary"]).destroy_all
        expect{Interactions::Users::CreateUserCalendarEvent.new.perform}.to change{user.calendar_events.where(event_type: CalendarEvent.event_types["anniversary"]).all.count}.by(0)
      end
    end

    context 'birthay' do
      let!(:custom_field) {create(:custom_field, :date_of_birth, company: company)}
      let!(:custom_field_value) {create(:custom_field_value, user: user, custom_field_id: custom_field.id, value_text: Date.today)}

      it 'should create a birthday calendar event' do
        expect{Interactions::Users::CreateUserCalendarEvent.new.perform}.to change{user.calendar_events.where(event_type: CalendarEvent.event_types["birthday"]).all.count}.by(1)
      end

      it 'should not create a birthday calendar event of future' do
        custom_field_value.update(value_text: Date.today + 2.days)
        expect{Interactions::Users::CreateUserCalendarEvent.new.perform}.to change{user.calendar_events.where(event_type: CalendarEvent.event_types["birthday"]).all.count}.by(0)
      end

      it 'should not create a birthday calendar event of past' do
        custom_field_value.update(value_text: Date.today - 2.days)
        expect{Interactions::Users::CreateUserCalendarEvent.new.perform}.to change{user.calendar_events.where(event_type: CalendarEvent.event_types["birthday"]).all.count}.by(0)
      end

      it 'should not create a birthday calendar if there is no birthday event' do
        user.calendar_events.where(event_type: CalendarEvent.event_types["birthday"]).destroy_all
        expect{Interactions::Users::CreateUserCalendarEvent.new.perform}.to change{user.calendar_events.where(event_type: CalendarEvent.event_types["birthday"]).all.count}.by(0)
      end
    end

    context 'both' do
      let!(:custom_field) {create(:custom_field, :date_of_birth, company: company)}
      let!(:custom_field_value) {create(:custom_field_value, user: user, custom_field_id: custom_field.id, value_text: Date.today)}

      it 'should create both calendar event' do
        user.update(start_date: Date.today)
        expect{Interactions::Users::CreateUserCalendarEvent.new.perform}.to change{user.calendar_events.where(event_type: [CalendarEvent.event_types["birthday"], CalendarEvent.event_types["anniversary"]]).all.count}.by(2)
      end

      it 'should not create events if user is inactive' do
        user.update(start_date: Date.today, state: "inactive")
        expect{Interactions::Users::CreateUserCalendarEvent.new.perform}.to change{user.calendar_events.where(event_type: [CalendarEvent.event_types["birthday"], CalendarEvent.event_types["anniversary"]]).all.count}.by(0)
      end
    end
  end
end
