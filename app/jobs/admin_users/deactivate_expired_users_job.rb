module AdminUsers
  class DeactivateExpiredUsersJob < ApplicationJob

    def perform
      Interactions::AdminUsers::DeactivateExpiredUsers.new.perform
    end
  end
end
