module Users
  class SendWelcomeEmailJob < ApplicationJob
    def perform
      Interactions::Users::SendWelcomeEmail.new.perform
    end
  end
end
