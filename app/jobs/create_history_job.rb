class CreateHistoryJob < ApplicationJob
  queue_as :default

  def perform(user)
    message = I18n.t("history_notifications.email.user_invited", full_name: user.full_name)
    History.create_history({
      company: user.company,
      user_id: user.id,
      description: message,
      attached_users: [user.id]
    })
  end
end
