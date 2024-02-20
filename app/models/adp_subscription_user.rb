class AdpSubscriptionUser < ApplicationRecord
  belongs_to :adp_subscription

  def self.find_adp_subscription(organization_oid = nil, env)
    AdpSubscription.find_by(organization_oid: organization_oid, env: env.try(:upcase))
  end

  def self.assign_user(data, env)
    organization_oid = data['event']['payload']['configuration']['entry'][0]['value'] rescue nil
    adp_subscription = self.find_adp_subscription(organization_oid, env)

    zip_code = data['event']['payload']['user']['attributes']['entry'][0]['value'] rescue nil
    bill_rate = data['event']['payload']['user']['attributes']['entry'][1]['value'] rescue nil
    password = BCrypt::Password.create(data['event']['payload']['user']['attributes']['entry'][2]['value']) rescue nil
    app_admin = data['event']['payload']['user']['attributes']['entry'][3]['value'] rescue nil
    timezone = data['event']['payload']['user']['attributes']['entry'][4]['value'] rescue nil
    access_rights = data['event']['payload']['user']['attributes']['entry'][5]['value'] rescue nil
    username = data['event']['payload']['user']['attributes']['entry'][6]['value'] rescue nil
    title = data['event']['payload']['user']['attributes']['entry'][7]['value'] rescue nil
    department = data['event']['payload']['user']['attributes']['entry'][8]['value'] rescue nil
    identification_number = data['event']['payload']['user']['attributes']['entry'][9]['value'] rescue nil
    email = data['event']['payload']['user']['email'] rescue nil
    first_name = data['event']['payload']['user']['firstName'] rescue nil
    last_name = data['event']['payload']['user']['lastName'] rescue nil
    uuid = data['event']['payload']['user']['uuid'] rescue nil

    adp_subscription.adp_subscription_users.create(zip_code: zip_code, bill_rate: bill_rate, password: password, app_admin: app_admin,
      timezone: timezone, username: username, title: title, department: department, email: email, first_name: first_name,
      last_name: last_name, uuids: uuid, identification_number: identification_number, access_rights: access_rights, response_data: data)
  end

  def self.unassign_user(data, env)
    organization_oid = data['event']['payload']['configuration']['entry'][0]['value'] rescue nil
    adp_subscription = find_adp_subscription(organization_oid, env)

    uuid = data['event']['payload']['user']['uuid'] rescue nil
    adp_subscription_user = adp_subscription.adp_subscription_users.find_by(uuids: uuid)
    adp_subscription_user.destroy if adp_subscription_user.present?
  end
end
