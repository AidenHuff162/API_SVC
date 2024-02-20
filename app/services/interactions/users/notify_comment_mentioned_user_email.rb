module Interactions
  module Users
    class NotifyCommentMentionedUserEmail
      attr_reader :comment

      def initialize(comment)
        @comment = comment
      end

      def perform
        company = @comment.company
        if company
          mentioned_users = company.users.where(id: @comment.mentioned_users)
          mentioned_users.try(:find_each) do |mentioned_user|
            UserMailer.notify_comment_mentioned_user(mentioned_user, @comment).deliver_later!
          end
        end
      end
    end
  end
end
