module WebhooksSerializer
  class ForDialog < ActiveModel::Serializer
    attributes :id, :event, :target_url, :configurable, :filters, :description, :webhook_key, :zapier
  end
end
