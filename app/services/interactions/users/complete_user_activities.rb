module Interactions
  module Users
    class CompleteUserActivities
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def perform
        TaskUserConnection.where(user_id: user.id, state: 'in_progress').find_each do |task|
          task.complete
        end

        user.reload
        if user.stage_onboarding?
          user.onboarding!
        end

      end
    end
  end
end
