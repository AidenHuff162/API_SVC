module Interactions
  module Users
    class DocumentAssignedEmail
      attr_reader :user, :document_name, :co_signer

      def initialize(data)
        @user = User.find_by(id: data[:id])
        @co_signer = User.find_by(id: data[:co_signer_id]) if data[:co_signer_id]
        return unless @user

        if data[:document_type] == 'document_upload_request'
          @document = @user.user_document_connections.find(data[:document_id])
          @document_name = @document.try(:document_connection_relation).try(:title)
          @document_due_date = @document.try(:due_date)
        else
          paperwork_request = @user.paperwork_requests.find(data[:document_id])
          if data[:document_type] == 'paperwork_request'
            @document_name = paperwork_request.try(:document).try(:title)
            @document_due_date = paperwork_request.due_date
          elsif data[:document_type] == 'bulk_paperwork_packet_request' && !data[:co_signer_id]
            @document_name = paperwork_request.try(:paperwork_packet).try(:name)
            @document_due_date = paperwork_request.due_date
          elsif data[:document_type] == 'bulk_paperwork_packet_request' && data[:co_signer_id]
            @document_name = paperwork_request.try(:document).try(:title)
            @document_due_date = paperwork_request.due_date
          end
        end
      end

      def perform
        UserMailer.document_assigned_email(@user, @document_name, @co_signer, @document_due_date).deliver_now! if @document_name.present?
      end
    end
  end
end
