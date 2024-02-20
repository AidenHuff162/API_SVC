class WebhooksPayloadManagement
  include WebhookHandler

  attr_reader :company

  @@default_fields_mapper = {
    first_name: "fn",
    last_name: "ln",
    preferred_name: "pn",
    email: "ce",
    personal_email: 'pe',
    start_date: 'sd',
    team_id: "dpt",
    title: "jt",
    location_id: "loc",
    manager_id: "man",
    termination_date: "td",
    last_day_worked: "ltw",
    state: "st",
    github: "gh",
    twitter: "twt",
    about_you: "abt",
    linkedin: "lin"
  }

  def initialize(company_id)
    @company = Company.find(company_id)
  end

  def webhook_payload_data(default_field_names, user_id, old_user, old_custom_field_data, temp_profile = nil)
    old_user = old_user&.with_indifferent_access
    user = User.find(user_id)
    default_profile_fields = {}
    default_user_fields = {}
    default_job_detail_fields = {}
    job_details_webhook = {}
    job_details_webhook.default_proc = -> (h, k) { h[k] = Hash.new(&h.default_proc) }
    temp_profile["id"] = user.id if temp_profile.present?
    default_field_names.each do |default_field|
      pref_field = company.prefrences['default_fields'].select { |f| f["id"] == @@default_fields_mapper["#{default_field}".to_sym] }&.first
      if pref_field && pref_field["profile_setup"] == "profile_fields"
        if  ['about_you', 'twitter', 'linkedin', 'github'].include?(default_field)
          default_profile_fields.merge!("#{default_field}": user.profile["#{default_field}"])
        else
          default_user_fields.merge!("#{default_field}": user["#{default_field}"])
        end
      elsif pref_field && pref_field["profile_setup"]
        custom_table = pref_field['custom_table_property']
        job_details_webhook["#{custom_table}"]['params'].merge!("#{default_field}": user["#{default_field}"])
        default_job_detail_fields.merge!("#{default_field}": user["#{default_field}"])
      end
    end

    send_updates_to_webhooks(company, {event_type: 'profile_changed', attributes: old_user, params_data: default_user_fields, profile_update: false}) if old_user.present? && default_user_fields.present?

    send_updates_to_webhooks(company, {event_type: 'profile_changed', attributes: temp_profile, params_data: default_profile_fields, profile_update: true}) if temp_profile.present? && default_profile_fields.present?

    old_custom_field_data.each do |cs_field|
      custom_field = CustomField.get_custom_field(company, cs_field['name'])
      custom_table_name = CustomTable.find(custom_field['custom_table_id'])&.custom_table_property if custom_field.present? && custom_field['custom_table_id'].present?

      next unless custom_field.present?

      new_value = user.get_custom_field_value_text(cs_field['name'])
      if custom_field.custom_section_id
        send_updates_to_webhooks(company, {event_type: 'custom_field', custom_field_id: custom_field.id, old_value: cs_field['old_value'], new_value: new_value, user_id: user.id })
      else
        job_details_webhook["#{custom_table_name}"][:data] = { field_names: [], field_values: [], api_field_ids: [], old_values: [], new_values: [], field_types: [] } if !job_details_webhook["#{custom_table_name}"].key?(:data)
        job_details_webhook["#{custom_table_name}"][:data][:field_names].push(cs_field['name'])
        job_details_webhook["#{custom_table_name}"][:data][:field_values].push(new_value)
        job_details_webhook["#{custom_table_name}"][:data][:api_field_ids].push(custom_field.api_field_id)
        job_details_webhook["#{custom_table_name}"][:data][:old_values].push(cs_field['old_value'])
        job_details_webhook["#{custom_table_name}"][:data][:new_values].push(new_value)
        job_details_webhook["#{custom_table_name}"][:data][:field_types].push(custom_field.field_type)
      end
    end
    
    job_details_webhook.each do |key, value|
      next if key.to_s.blank?
      ctus = CustomTable.where(custom_table_property: "#{key}")&.first&.name
      send_updates_to_webhooks(company, {event_type: 'job_details_changed', attributes: old_user, params_data: job_details_webhook["#{key}"]['params'], data: job_details_webhook["#{key}"][:data]&.deep_symbolize_keys, ctus_name: ctus, effective_date: Date.today })
    end
  end

end
