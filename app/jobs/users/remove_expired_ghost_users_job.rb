module Users
  class RemoveExpiredGhostUsersJob < ApplicationJob

    def perform
      Interactions::Users::RemoveExpiredGhostUsers.new.perform
    end
  end
end
