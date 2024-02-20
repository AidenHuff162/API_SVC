module CommentManagement
  extend ActiveSupport::Concern

  def send_email_to_mentioned_users(comment)
    Interactions::Users::NotifyCommentMentionedUserEmail.new(comment).perform if comment.mentioned_users.present?
  end

  def send_email_to_task_owner(comment)
    Interactions::Users::NotifyCommentTaskOwnerEmail.new(comment).perform
  end

  def update_comments_description(user)
    comments = user.company.comments.where("'#{user.id}' = ANY (mentioned_users)")
    return if !comments.present?

    comments.find_each do |comment|
      comment.update(description: comment.description.gsub("USERTOKEN[#{user.id}]", "@#{user.first_name}"))
    end
  end
end
