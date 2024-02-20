module UserEmailSerializer
  class Basic < ActiveModel::Serializer
    type :user_email

    attributes :subject, :sent_at, :status, :description, :message, :template_name, :editor, :id, :schedule_options,
    :email_type, :email_status, :send_to, :error_message, :to
    belongs_to :user, serializer: UserSerializer::Inbox

    def message
      ActionView::Base.full_sanitizer.sanitize(object.description).truncate(33) rescue ''
    end

    def sent_at
      sent_at =  @instance_options[:tab] == 'scheduled' ? object.invite_at : object.sent_at
      date = @instance_options[:company].convert_time(sent_at.to_date) rescue ''
      # if object.email_type == 'offboarding'
        # time = sent_at.in_time_zone(@instance_options[:company].time_zone).strftime("%I:%M %p") rescue ''
      # else
        time = sent_at.strftime("%I:%M %p") rescue ''
      # end
      {date: date, time: time}
    end

    def editor
      sent_at =  @instance_options[:tab] == 'scheduled' ? (object.updated_at || object.created_at) : nil
      date = @instance_options[:company].convert_time(sent_at.to_date) rescue ''
      if sent_at
        date = sent_at.strftime("%m/%d/%Y") rescue ''
        editor = object.editor.display_name rescue ''
      end
      {date: date, name: editor}
    end

    def status
      if @instance_options[:tab] == 'sent'
        status = object.activity['status'].present? ? object.activity['status'] : ''
        times = status == 'Opened' ? (object.activity['opens'].to_s + ' times') : ''
        {status: status, times: times}
      end
    end

    def send_to
      to_emails = object.to.compact
      to_emails.present? ? to_emails : object.get_to_email_list
    end

    def error_message
      if object.email_status == UserEmail.statuses[:incomplete] && object.schedule_options['send_email'] == UserEmail.send_emails[:relative_key]
        object.check_valid_schedule_options
      end
    end
  end
end
