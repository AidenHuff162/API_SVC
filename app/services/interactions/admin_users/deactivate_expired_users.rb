module Interactions
  module AdminUsers
    class DeactivateExpiredUsers
      def perform
        expired_admin_users = AdminUser.where("expiry_date <= ?", Date.today)
        expired_admin_users.update_all(state: 'inactive') if expired_admin_users.present?
      end
    end
  end
end
