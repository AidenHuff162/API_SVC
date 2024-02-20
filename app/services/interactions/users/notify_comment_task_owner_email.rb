module Interactions
  module Users
    class NotifyCommentTaskOwnerEmail
      attr_reader :comment

      def initialize(comment)
        @comment = comment
      end

      def perform
        UserMailer.notify_comment_task_owner(@comment).deliver_later!
      end
    end
  end
end
