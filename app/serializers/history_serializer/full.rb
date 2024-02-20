module HistorySerializer
  class Full < ActiveModel::Serializer
    attributes :id, :description, :created_by, :created_at, :creation_date, :integration_type, :is_created, :company_timezone,
     :description_count, :event_type, :email_type, :is_job_id_exist, :schedule_time, :schedule_date, :schedule_email_at

    belongs_to :company, serializer: CompanySerializer::History
    belongs_to :user, serializer: UserSerializer::History
    has_many :history_users, serializer: HistoryUserSerializer::Base

    def creation_date
      object.created_at.in_time_zone(object.company.time_zone).to_date
    end

    def company_timezone
      Time.now.in_time_zone(object.company.time_zone).strftime("%z")
    end

    def is_job_id_exist
      if object.schedule_email_at.present?
        schedule_email_at = object.schedule_email_at.to_datetime
        schedule_email_at = schedule_email_at.utc.change(offset: ActiveSupport::TimeZone[object.company.time_zone].formatted_offset(false))
      end
        (object.job_id.present? || object.user_email_id.present?) && object.schedule_email_at.present? && schedule_email_at > Time.now
    end

    def schedule_time
      object.schedule_email_at.strftime("%l:%M%P").gsub("\s", "") if object.schedule_email_at
    end

    def schedule_date
      object.schedule_email_at.strftime("%Y-%m-%d") if object.schedule_email_at
    end
  end
end
