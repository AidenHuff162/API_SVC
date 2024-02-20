module Users
  class CreateUserCalendarEventJob < ApplicationJob
    def perform
      Interactions::Users::CreateUserCalendarEvent.new.perform
    end
  end
end
