class AdpSubscription < ApplicationRecord
  has_many :adp_subscription_users, dependent: :destroy

  def self.create_subscription(data = nil, env)
    event_type = data['event']['type'] rescue nil
    subscriber_first_name = data['event']['creator']['firstName'] rescue nil
    subscriber_last_name = data['event']['creator']['lastName'] rescue nil
    subscriber_email = data['event']['creator']['email'] rescue nil
    subscriber_uuid = data['event']['creator']['uuid'] rescue nil
    company_name = data['event']['payload']['company']['name'] rescue nil
    company_uuid = data['event']['payload']['company']['uuid'] rescue nil
    organization_oid = data['event']['payload']['configuration']['entry'][0]['value'] rescue nil
    associate_oid = data['event']['payload']['configuration']['entry'][2]['value'] rescue nil
    no_of_users = data['event']['payload']['order']['item']['quantity'] rescue nil

    AdpSubscription.create(event_type: event_type, subscriber_first_name: subscriber_first_name, subscriber_last_name: subscriber_last_name,
      subscriber_email: subscriber_email, subscriber_uuid: subscriber_uuid, company_name: company_name, company_uuid: company_uuid,
      organization_oid: organization_oid, no_of_users: no_of_users, associate_oid: associate_oid, response_data: data, env: env.try(:upcase))
  end

  def self.change_subscription(data = nil, env)
    event_type = data['event']['type'] rescue nil
    subscriber_first_name = data['event']['creator']['firstName'] rescue nil
    subscriber_last_name = data['event']['creator']['lastName'] rescue nil
    subscriber_email = data['event']['creator']['email'] rescue nil
    subscriber_uuid = data['event']['creator']['uuid'] rescue nil
    organization_oid = data['event']['payload']['configuration']['entry'][0]['value'] rescue nil
    associate_oid = data['event']['payload']['configuration']['entry'][2]['value'] rescue nil
    no_of_users = data['event']['payload']['order']['item']['quantity'] rescue nil

    adpSubscription = AdpSubscription.find_by(organization_oid: organization_oid, env: env.try(:upcase))
    adpSubscription.update(subscriber_first_name: subscriber_first_name, subscriber_last_name: subscriber_last_name, subscriber_email: subscriber_email,
      subscriber_uuid: subscriber_uuid, event_type: event_type, no_of_users: no_of_users, associate_oid: associate_oid, response_data: data, env: env.try(:upcase))
  end

  def self.cancel_subscription(data = nil, env)
    organization_oid = data['event']['payload']['configuration']['entry'][0]['value'] rescue nil
    associate_oid = data['event']['payload']['configuration']['entry'][2]['value'] rescue nil

    adpSubscription = AdpSubscription.find_by(organization_oid: organization_oid, associate_oid: associate_oid, env: env.try(:upcase))
    adpSubscription.destroy
  end
end
