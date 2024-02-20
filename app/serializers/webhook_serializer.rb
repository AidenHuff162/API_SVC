class WebhookSerializer < ActiveModel::Serializer
  attributes :response_data, :integeration_name, :action
end
