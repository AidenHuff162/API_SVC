module HistoryHandler
  extend ActiveSupport::Concern

  def create_document_history(company, user, document_name, action)
    return unless company.present? || user.present? || document_name.present? || action.present?
    
    history_message = case action.downcase
                      when 'create'
                        'history_notifications.document.created'
                      when 'add'
                        'history_notifications.document.added'
                      when 'update'
                        'history_notifications.document.updated'
                      when 'complete'
                        'history_notifications.document.completed'
                      when 'delete'
                        'history_notifications.document.deleted'
                      when 'finalize'
                        'history_notifications.document.finalized'
                      else
                        ''
                      end

    History.create_history({
      company: company,
      user_id: user.id,
      description: I18n.t(history_message, document_name: document_name, user_name: user.full_name)
    })
  end
end
