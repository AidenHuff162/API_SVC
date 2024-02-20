module ActivitySerializer
  class Full < ActiveModel::Serializer
    attributes :description, :time, :created_at
    belongs_to :agent, serializer: UserSerializer::History
    belongs_to :workspace, serializer: WorkspaceSerializer::Minimal

    def time
      time_difference = Time.now - object.created_at
      case time_difference
        when 0 .. 59
          I18n.t("comment.just_now")
        when 60 .. (3600-1)
          I18n.t("comment.mins_ago", count: (time_difference/60).round)
        when 3600 .. (3600*24-1)
          I18n.t("comment.hours_ago", count: (time_difference/3600).round)
        else
          created_time = object.created_at.to_datetime.utc.change(offset: ActiveSupport::TimeZone[@instance_options[:company].time_zone].formatted_offset(false)).utc
          created_time.strftime("%b %d %Y, %I:%M %p")
      end
    end
  end
end
