module Interactions
  module Users
    class RemoveExpiredGhostUsers
      def perform
        expired_users = User.where('expires_in IS NOT NULL AND expires_in <?', Date.today)
        expired_users.each do |u|
          u.destroy
        end
      end
    end
  end
end
