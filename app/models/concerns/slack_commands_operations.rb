module SlackCommandsOperations
  extend ActiveSupport::Concern

  def get_team_details_on_slack
    users_list = self.managed_users_working.includes(:company).order('start_date DESC')
    message = {blocks: [{"type": "section","text": {"type": "mrkdwn","text": "*Team details*"}}]}
    if users_list.present?
      blocks = message[:blocks]
      users_list.each_with_index do |user, index|
        if index !=0
          blocks.push({"type": "divider"})
        end
        blocks.push(user.get_subordinate_message_block)
      end
    else
      message = message_for_nick
    end
    message
  end

  def get_slack_user_id(integration)
    client = Slack::Web::Client.new
    client.token = integration.slack_bot_access_token
    user_on_slack = client.users_lookupByEmail({email: self.email || self.personal_email})
    slack_user_id = nil
    if user_on_slack &&  user_on_slack['ok']
      slack_user_id =  user_on_slack['user']['id']
    end
    slack_user_id
  end

  def prepare_time_off_request_message(request)
    pto_policy = request.pto_policy
    dates = TimeConversionService.new(self.company).format_pto_dates(request.begin_date, request.get_end_date)
    pto_length =  @request_length
    leftover_balance =  pto_policy.unlimited_policy ? 'Unlimited' : request.calculate_carryover_balance
    key = SecureRandom.hex
    crypt = ActiveSupport::MessageEncryptor.new(key)
    approve_data = "approved_#{request.id}" #approved_requestID_ApprovedBYID
    denied_data = "denied_#{request.id}" #denied_requestID_ApprovedBYID
    encrypted_data_approved = crypt.encrypt_and_sign(approve_data)
    encrypted_data_denied = crypt.encrypt_and_sign(denied_data)
    action = {
      "blocks": [
        {
          "type": "section",
          "block_id": "time_off_request_approve_deny",
          "text": {
            "type": "mrkdwn",
            "text": "You have a new request:\n*<https://#{self.company.app_domain}/#/time_off/#{request.user_id}| #{request.user.display_name} - Time Off request>*"
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "*Type:*\n#{pto_policy.name}\n*When:*\n#{dates}\n*Length:* #{request.get_request_length}\n*Remaining Amount:* #{leftover_balance}\n #{request.comments.present? ? ('*Comment:* ' + request.comments.first.description) : ''}"
          }
        },
        {
          "type": "actions",
          "elements": [
            {
              "type": "button",
              "text": {
                "type": "plain_text",
                "emoji": true,
                "text": "Approve"
              },
              "style": "primary",
              "value": "#{key}_#{encrypted_data_approved}"
            },
            {
              "type": "button",
              "text": {
                "type": "plain_text",
                "emoji": true,
                "text": "Deny"
              },
              "style": "danger",
              "value": "#{key}_#{encrypted_data_denied}"
            }
          ]
        }
      ]
    }
    return action
  end

  def respond_approve_time_off_request(payload)
    message = {}
    message = {blocks: payload['message']['blocks'].first(2)} #Do not need actions elements
    action_value = payload['actions'][0]['value']
    encrypted_data = action_value.split("_")
    crypt = ActiveSupport::MessageEncryptor.new(encrypted_data.first)
    action_and_ids = crypt.decrypt_and_verify(encrypted_data.last).split("_")  #[Approve/Deny, requestID, Approval ID]
    pto_request = PtoRequest.find_by(id: action_and_ids[1]) if action_and_ids && action_and_ids[1]
    if pto_request.present?
      if action_and_ids[0] == 'approved'
        PtoRequestService::CrudOperations.new.approve_or_deny(pto_request, 1, self, false, "slack")
        message[:blocks].push({"type": "section","text": {"type": "mrkdwn","text": "*Approved:* :+1::skin-tone-5:"}})
      else
        PtoRequestService::CrudOperations.new.approve_or_deny(pto_request, 2, self, false, "slack")
        message[:blocks].push({"type": "section","text": {"type": "mrkdwn","text": "*Rejected:* :-1::skin-tone-5:"}})
      end

    else
      message[:blocks].push({"type": "section","text": {"type": "mrkdwn","text": "*This time off request is not present on Sapling.*"}})
    end
    message
  end

  def get_subordinate_message_block
    return {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "<https://#{self.company.app_domain}/#/profile/#{self.id}| #{self.display_name}>"
      },
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Title*"
        },
        {
          "type": "mrkdwn",
          "text": "*Status*"
        },
        {
          "type": "mrkdwn",
          "text": "#{self.title.blank? ? ' ' : self.title}"
        },
        {
          "type": "mrkdwn",
          "text": "#{self.is_on_leave? == nil ? 'In Office' : 'Out of Office'}"
        }
      ]
    }
  end

  def get_user_policy_block(policy)
    amount = policy.unlimited_policy ? 'Unlimited' : policy.available_hours_with_carryover(self)
    return {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Policy Name:* #{policy.name rescue ' '}\n*Amount Available:* #{amount}"
      }
    }
  end

  def get_policies_for_slack(time_off_policies_count = 0, payload = nil)
    if self.company.enabled_time_off
      if self.pto_policies.length > 0
        return payload.present? ? update_existing_message_for_available_slack_policies(payload) : create_new_message_for_available_slack_policies(time_off_policies_count)
      else
        return {text: "*You do not have any time off policy*"}
      end
    else
      return time_off_disable_message
    end
    ''
  end

  def get_tasks_for_slack(integration, type)
    message = nil
    tasks = []
    TaskUserConnection.incomplete_tasks(self.company_id, self.id).each do |tuc|
      tasks.push(tuc.task) if tuc.task.present?
    end

    message_content = {
      type: "assign_task",
      tasks: tasks
    }
    return unless integration.present?
    slack = SlackService::BuildMessage.new(self, self.company, integration)
    attachments = slack.prepare_attachments(message_content)
    unless attachments.nil? || attachments.empty?
      begin
        Integrations::SlackNotification::Push.push_notification(attachments, self.company, integration, false, type)
      rescue Exception => e
        puts "--------------------- Slack Notification --------------------"
        p e
      end
    else
      message = {text: "*You have no tasks to complete.*"}
    end

    message
  end

  def get_team_out_of_office_details
    company = self.company
    if company.enabled_time_off
      managed_users_list = self.managed_users_working
      if managed_users_list.length > 0
        @message = date_range_block_for_slack
        start_date, end_date = company.time.to_date, company.time.to_date + 7.days
        prepare_ooo_requests_block_for_daterange(start_date, end_date)
        return @message
      else
        return message_for_nick
      end
    else
      return time_off_disable_message
    end
  end

  def respond_out_of_office(payload)
    @payload = payload
    @message = {}
    @message = {blocks: [@payload['message']['blocks'][0]]}
    if validte_start_and_end_date?
      prepare_ooo_requests_block_for_daterange(@start_date, @end_date)
    else
      @message[:blocks].push({"type": "section","text": {"type": "mrkdwn","text": "`End date should be greater than start date.`"}})
    end
    @message
  end

  def initialize_client
    @integration = Integration.where(api_name: 'slack_notification').take
    @client = Slack::Web::Client.new
    @client.token = @integration.slack_bot_access_token
  end

  def save_pto_request(payload)
    message = {}
    User.current = self

    params = prepare_pto_request_params(payload, self)
    pto_request = PtoRequest.new(params)

    params['balance_hours'] = pto_request.get_balance_used if params['balance_hours'] == '0' || params['balance_hours'].to_f > pto_request.get_balance_used.to_f && params['partial_day_included'].blank?
    message[:text] = 'Balance Hours must not be less than or equal to 0.' if params['balance_hours'].to_f <= 0.0
    message[:text] = 'Begin date must be less than End date.' if params['begin_date'] > params['end_date']
    message[:text] = 'Requested time off is greater than the Lenght of workday.' if params['partial_day_included'].present? && params['balance_hours'].to_f > pto_request.get_balance_used

    if params['pto_policy_id'].present?
      policy = PtoPolicy.find_by(id: params['pto_policy_id'])
      if policy.present? && params['begin_date'].present? && !policy.working_days.include?(params['begin_date'].to_date.strftime("%A")) && params['end_date'].present? && !policy.working_days.include?(params['end_date'].to_date.strftime("%A"))
        message[:text] = 'Selected date does not include valid working days.'
      elsif policy.blank?
        message[:text] = 'Selected policy does not exist in the record.'
      end
    else
      message[:text] = 'Pto Policy must be selected.'
    end

    if message.blank?
      begin
        service_response = PtoRequestService::RestOps::CreateRequest.new(params, self.id).perform

        if service_response.errors.empty?
          LoggingService::GeneralLogging.new.create(pto_request.pto_policy.company, 'Slack PTO Creation', {result: "Successfully created pto policy for pto_request with id #{pto_request.id}", params: params, payload: payload}, 'PTO')
          message[:text] = "Pto Request Successfully created for the user #{self.preferred_full_name}"
        else
          LoggingService::GeneralLogging.new.create(pto_request.pto_policy.company, 'Slack PTO Creation', {result: "Failed to create pto policy for pto_request with id #{pto_request.id}", error: service_response.errors, params: params, payload: payload}, 'PTO')
          message[:text] = service_response.errors.full_messages.uniq.join(', ')
        end
      rescue Exception => e
        LoggingService::GeneralLogging.new.create(pto_request.pto_policy.company, 'Slack PTO Creation', {result: "Failed to create pto policy for pto_request with id #{pto_request.id}", error: e.message, params: params, payload: payload}, 'PTO')
        message[:text] = e.message
      end
    end

    User.current = nil
    message
  end

  def update_partial_day_view(integration, payload)
    message = {}
    partial_day_selected = payload['actions'][0]['selected_options'].length == 1
    params = prepare_pto_request_params(payload, self)
    params['partial_day_included'] = partial_day_selected
    view = prepare_new_pto_request_dialog(params)
    message["view"] = view
    message["view_id"] = payload["view"]["root_view_id"]
    url = 'https://slack.com/api/views.update'
    response=RestClient.post(url, message.to_json,{:content_type => 'application/json', :Authorization => "Bearer #{integration.slack_bot_access_token}"})
  end

  def send_timeoff_form(integration, main_payload)
    if self.company.enabled_time_off
      message = {}
      message["view"] = prepare_new_pto_request_dialog({'partial_day_included': false})
      message["trigger_id"] = main_payload[:payload]["trigger_id"]
      url = 'https://slack.com/api/views.open'
      response=RestClient.post(url, message.to_json,{:content_type => 'application/json', :Authorization => "Bearer #{integration.slack_bot_access_token}"})
      nil
    else
      time_off_disable_message
    end
  end

  private

  def time_off_disable_message
    {text: "*Your team is not using the Time Off functionality in Sapling*"}
  end

  def message_for_nick
    {text: "*You're not managing anyone*"}
  end

  def date_range_block_for_slack
    return { "blocks": [
      {"type": "actions","block_id": "out_of_office",
        "elements": [
          {"type": "datepicker",
            "action_id": "out_of_office_start",
            "initial_date": Date.today.strftime("%F"),
            "placeholder": {
              "type": "plain_text",
              "text": "Select start date"
            }
          },
          {
            "type": "datepicker",
            "action_id": "out_of_office_end",
            "initial_date": (Date.today + 7.days).strftime("%F"),
            "placeholder": {
              "type": "plain_text",
              "text": "Select end date"
            }
          }

        ]
      }
    ]}
  end

  def prepare_out_of_office_people_data data
    data[:starting_pto_team_members].each_with_index do |user_bolock, index|
      @message[:blocks].push({"type": "divider"}) unless index == 0
      @message[:blocks].push(out_of_office_bolck(user_bolock))
    end
  end

  def out_of_office_bolck user_bolock
    text = "<https://#{self.company.app_domain}/#/profile/#{user_bolock[:member_id]}| #{user_bolock[:member_name] + '  |  ' + user_bolock[:member_title].to_s}>\n\n"
    user_bolock[:pto_data].each do |pto_with_policy|
      text += "*#{pto_with_policy[:policy]}*\n"
      pto_with_policy[:policies].each do |pto|
        text += "• #{pto[:pto_amount]}. Starts #{pto[:pto_start_date]}, return #{pto[:pto_return_date]}\n"
      end
    end
    return {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": text
      }
    }
  end

  def validte_start_and_end_date?
    if @payload['actions'][0]['action_id'] == 'out_of_office_start'
      #Selected start date should be smaller than end date
      @start_date = @payload['actions'][0]['selected_date'].to_date
      @end_date = @payload['message']['blocks'][0]['elements'][1]['initial_date'].to_date
    elsif @payload['actions'][0]['action_id'] == 'out_of_office_end'
      @end_date = @payload['actions'][0]['selected_date'].to_date
      @start_date = @payload['message']['blocks'][0]['elements'][0]['initial_date'].to_date
    end
    return  @start_date <= @end_date
  end

  def prepare_ooo_requests_block_for_daterange(start_date, end_date)
    data =  WeeklyTeamDigestEmailService.new(self).get_team_out_of_office_data(start_date, end_date)
    if data.present?
      prepare_out_of_office_people_data data
    else
      @message[:blocks].push({"type": "section","text": {"type": "mrkdwn","text": "*No one is out for this time range.*"}})
    end
  end

  def date_picker_element(date_label, date)
    date_picker =  {
        "type": "input",
        "block_id": "#{date_label}_Date"
      }
    date_picker["element"] = {"type": "datepicker"}
    date_picker["element"]["initial_date"] = date
    date_picker["element"]["placeholder"] = prepare_element("Select a date")
    date_picker["label"] = prepare_element(date_label)
    date_picker["element"]["action_id"] = "#{date_label}_Date"

    date_picker
  end

  def prepare_element(text)
    element = {}
    element["type"] = "plain_text"
    element["text"] = "#{text}"
    element["emoji"] = true
    element
  end

  def pto_policies_element(option)
    data =  {
        "type": "input",
        "block_id": "pto_policy"
      }
    data["element"] = {"type": "static_select"}
    data["element"]["action_id"] = "pto_policy"
    data["element"]["placeholder"] = prepare_element("Select an item")
    options = []
    self.assigned_pto_policies.each do |policy|
      a = {}
      a["text"] = prepare_element(policy.pto_policy.name)
      a["value"] = policy.pto_policy.id.to_s
      options.push(a)

      if option.present? && option == policy.pto_policy.id.to_s
        data["element"]["initial_option"] = a
      end
    end

    data["element"]["options"] = options
    data["label"] = prepare_element("Pto Policy")

    data
  end

  def notes_element
    notes = {"type": "input", "block_id": "notes"}
    notes["element"] = { "type": "plain_text_input" }
    notes["element"]["placeholder"] = prepare_element("Add a comment or question about the request")
    notes["label"] = prepare_element("Your note to your manager")
    notes["element"]["action_id"] = "notes"
    notes["optional"] = true

    notes
  end

  def hours_element(value)
    hours = {"type": "input", "block_id": "hours"}
    hours["element"] = { "type": "plain_text_input" }
    hours["element"]["placeholder"] = prepare_element("Enter Number of Hours")
    hours["label"] = prepare_element("Partial Hours")
    hours["element"]["action_id"] = "hours_element"
    hours["element"]["initial_value"] = value if value.present?

    hours
  end

  def partial_day_included
    partial = {"type": "actions", "block_id": "partial_day_included"}

    element = { "type": "checkboxes"}
    element["action_id"] = "partial_day_included"
    element["options"] = [{"text": prepare_element("This request includes partial hours")}]
    partial["elements"] = [element]

    partial
  end

  def prepare_pto_request_params(payload, user)
    params = {}
    params['begin_date'] = payload['view']['state']['values']['Begin_Date']['Begin_Date']['selected_date'] rescue Date.today
    params['end_date'] = payload['view']['state']['values']['End_Date']['End_Date']['selected_date'] rescue params['begin_date']
    params['pto_policy_id'] = payload['view']['state']['values']['pto_policy']['pto_policy']['selected_option']['value'] rescue nil
    comment = {}
    description = payload['view']['state']['values']['notes']['notes']['value'] rescue nil
    if description
      comment['description'] = description
      comment['commenter_id'] = user.id
      comment['mentioned_users'] = []
      params['comments_attributes'] = [comment]
    end
    params['user_id'] = user.id
    params['balance_hours'] = payload['view']['state']['values']['hours']['hours_element']['value'] rescue '0'
    params['partial_day_included'] = payload['view']['state']['values']['End_Date']['End_Date']['selected_date'].present? ? false : true rescue true
    params['attachment_ids'] = []

    params
  end

  def prepare_new_pto_request_dialog(params={})
    view = {
        "type": "modal",
        "callback_id": "submit_pto_request"

      }

    view["title"]= prepare_element("New Time Off Request")
    view["submit"]= prepare_element("Submit")
    view["close"]= prepare_element("Cancel")

    view["blocks"] = []
    view["blocks"].push pto_policies_element(params[:pto_policy_id])
    view["blocks"].push date_picker_element("Begin", params[:begin_date] || Date.today)
    view["blocks"].push date_picker_element("End", params[:end_date] || Date.today) if !params['partial_day_included'].present?
    view["blocks"].push partial_day_included
    view["blocks"].push hours_element(params['balance_hours']) if params['partial_day_included'].present?
    view["blocks"].push notes_element

    view
  end

  def create_new_message_for_available_slack_policies(time_off_policies_count)
    message = {blocks: []}
    message[:blocks].push({"type": "section", "text": {"type": "mrkdwn","text": "*Available Balance as of "+Date.today.strftime(self.company.get_date_format())+"*"}}) if time_off_policies_count == 0

    remaining_pto_count = self.pto_policies.count - time_off_policies_count
    i = 1

    if remaining_pto_count > 24
      maximum_policies = time_off_policies_count == 0 ? 23 : 24
      break_flag = true
    else
      break_flag = false
    end

    self.pto_policies.order(:id).offset(time_off_policies_count).each_with_index do |policy, index|
      break if break_flag && i > maximum_policies
      message[:blocks].push({"type": "divider"}) unless index == 0
      message[:blocks].push(self.get_user_policy_block(policy))
      i += 1
    end

    if break_flag && i > maximum_policies
      time_off_policies_count += maximum_policies
      message[:blocks].push({"type": "section","text": {"type": "mrkdwn","text": ""+self.company.name+" has "+(remaining_pto_count - maximum_policies).to_s+" more policies not shown here."}})
      message[:blocks].push({"type": "actions", "elements": [{"type": "button", "text": {"type": "plain_text", "text": "Show More"}, "style": "primary", "value": time_off_policies_count.to_s, "action_id": "timeoff_show_more"}]})
    end
    return message
  end

  def update_existing_message_for_available_slack_policies(payload)
    payload['message']['blocks'].delete(payload['message']['blocks'].last)
    message = {blocks: payload['message']['blocks']}
    return message
  end
end
