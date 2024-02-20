module WebhooksSerializer
  class ForTable < ActiveModel::Serializer
    type :webhook

    attributes :id, :get_event, :target_url, :applies_to, :last_triggered_at, :get_state, :created, :description, :configurables
    
    def read_attribute_for_serialization(attr)
      if object.key? attr.to_s
        attr.to_s == 'filters' ? JSON.parse(object['filters']) : object[attr.to_s]
      else
        self.send(attr) rescue nil
      end
    end

    def configurables
      configurable_fields = nil
      if object["configurable"].present?
        configurable_fields = Webhook.get_configurables(JSON.parse(object["configurable"]), instance_options[:company])
      end
      configurable_fields
    end

    def get_state
      Webhook.states.key(object["state"]).gsub("_"," ")
    end

    def get_event
      Webhook.events.key(object["event"]).gsub("_"," ")
    end

    def filters
      @filters ||= JSON.parse(object['filters'])
    end

    def applies_to
      applies_to = Webhook.get_applied_to_locations(filters, instance_options[:company]) + Webhook.get_applied_to_teams(filters, instance_options[:company]) + Webhook.get_applied_to_statuses(filters, instance_options[:company])
    end

    def created
      if object["created_at"].present?
        created_at = Webhook.get_formatted_date_time(object["created_at"], @instance_options[:company], false)
        created_at[:date] + ' ' + created_at[:time]
      else 
        nil
      end
    end

    def last_triggered_at
      if object["triggered_at"].present?
        Webhook.get_formatted_date_time(object["triggered_at"], @instance_options[:company], true)
      else 
        nil
      end
    end
  end
end
