module WebhookEventsSerializer
  class Simple < ActiveModel::Serializer
    attributes :id, :triggered_at, :response_status, :event_id, :status, :created_at

    def status
      if object.failed?
        "Error"
      elsif object.succeed?
        "Active"
      else
        object.status
      end
    end

    def created_at
      if object.created_at.present?
        WebhookEvent.get_formatted_date_time(object.created_at, @instance_options[:company])
      else 
        nil
      end
    end

    def triggered_at
      if object.triggered_at.present?
        WebhookEvent.get_formatted_date_time(object.triggered_at, @instance_options[:company])
      else 
        nil
      end
    end
  end
end
