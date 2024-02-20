module WebhookEventsSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :triggered_at, :response_status, :status, :request_body, :response_body

    def response_body
      object.response_body.present? ? JSON.pretty_generate(object.response_body) : "{}"
    end

    def request_body
      object.request_body.present? ? JSON.pretty_generate(object.request_body) : "{}"
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
