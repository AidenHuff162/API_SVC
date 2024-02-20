module Interactions
  module Users
    class OffboardUser
      include UserOffboardManagement

      def perform
        Company.where(id: fetch_company_ids).find_each do |company|
          users = company.fetch_removed_access_user
          users.find_each(batch_size: 100) do |user|
            terminate_user(user)
          end
        end
      end

      def fetch_company_ids
        Company.all.joins(:users).where("(users.current_stage != ? AND (users.termination_date IS NOT NULL) AND (last_offboarding_event_date IS NULL OR last_offboarding_event_date != ?)) OR (users.remove_access_state = ? AND users.current_stage = ?)", User.current_stages[:departed], Time.now.utc.to_date, User.remove_access_states[:pending], User.current_stages[:departed]).ids.uniq
      end
    end
  end
end
