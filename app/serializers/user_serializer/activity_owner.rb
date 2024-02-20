module UserSerializer
  class ActivityOwner < Base
    attributes :id, :picture, :email, :activity_count, :title, :display_name_format
    has_one :location, serializer: LocationSerializer::Basic

    def activity_count
      if @instance_options[:type] == 'task'
        TaskUserConnection.where(task_id: @instance_options[:activity_id], owner_id: object.id, state: 'in_progress').count
      elsif @instance_options[:type] == 'document'
        PaperworkRequest.where("document_id= ? AND requester_id= ? AND (state= 'assigned' OR (state= 'signed' AND co_signer_id IS NOT NULL))", @instance_options[:activity_id], object.id).count
      elsif @instance_options[:type] == 'upload'
        UserDocumentConnection.joins(document_connection_relation: :document_upload_request).where("document_upload_requests.id= ? AND document_upload_requests.user_id= ? AND state = 'request'", @instance_options[:activity_id], object.id).count
      end
    end

    def display_name_format
      object.company.display_name_format
    end
  end
end
