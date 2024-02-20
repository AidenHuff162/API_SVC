module Users
  class OffboardUserJob < ApplicationJob
    def perform
      Interactions::Users::OffboardUser.new.perform
    end
  end
end
