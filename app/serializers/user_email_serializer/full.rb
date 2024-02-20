module UserEmailSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :subject, :cc, :bcc, :description, :invite_at, :from, :to, :time_zone, :schedule_options, :email_type, :email_status, :template_name, :template_attachments, :is_template_exist
    has_many :attachments, serializer: AttachmentSerializer

    def time_zone
      if object.schedule_options["send_email"].present? && object.schedule_options["send_email"] == 2 && object.schedule_options['time_zone'].present?
        object.schedule_options["time_zone"]
      else
        @instance_options[:company].time_zone
      end
    end
    def is_template_exist
      return nil unless object.template_name.present?
      object.is_template_exist(object.template_name, @instance_options[:company].id)
    end
  end
end