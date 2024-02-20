module CompanySerializer
  class WebhookPage < ActiveModel::Serializer
    attributes :id, :name, :webhook_token, :webhook_feature_flag, :zapier_feature_flag

    def webhook_token
      if object.webhook_token.present?
        if @instance_options[:token_visible] 
          object.webhook_token
        else
          '*' * object.webhook_token.length
        end
      else
        nil
      end
    end
  end
end
