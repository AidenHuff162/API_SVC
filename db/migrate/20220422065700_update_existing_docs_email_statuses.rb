class UpdateExistingDocsEmailStatuses < ActiveRecord::Migration[5.1]
  def change
    puts '----- Update Existing Docs Email Statuses Migration Started -----'
    
    PaperworkRequest.where(email_status: nil).each do |pr|
      email_status_value = ''
      if (pr.draft? || pr.preparing? || pr.failed?)
        email_status_value = 'email_not_sent'
      elsif pr.assigned?
        email_status_value = pr.co_signer_id.nil? ? 'email_completely_sent' : 'email_partially_sent'        
      elsif (pr.signed? || pr.all_signed?)
        email_status_value = 'email_completely_sent'        
      end
      
      pr.update_column(:email_status, email_status_value) if email_status_value.present?
    end

    UserDocumentConnection.where(email_status: nil).each do |udc|
      email_status_value = ''
      if udc.draft?
        email_status_value = 'email_not_sent'
      elsif (udc.request? || udc.completed?)
        email_status_value = 'email_completely_sent'        
      end
      
      udc.update_column(:email_status, email_status_value) if email_status_value.present?
    end

    puts '----- Update Existing Docs Email Statuses Migration Completed -----'
  end
end
