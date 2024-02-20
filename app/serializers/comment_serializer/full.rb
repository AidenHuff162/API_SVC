module CommentSerializer
  class Full < ActiveModel::Serializer
    attributes :description, :mentioned_users, :time, :pto_activities
    belongs_to :commenter, serializer: UserSerializer::History

    def mentioned_users
      if object.mentioned_users.present?
        users = object.company.users.where(id: object.mentioned_users)
        ActiveModelSerializers::SerializableResource.new(users, each_serializer: UserSerializer::HistoryUser) if users
      end
    end

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
          created_time = object.created_at.to_datetime.utc.change(offset: ActiveSupport::TimeZone[object.company.time_zone].formatted_offset(false)).utc
          created_time.strftime("%b %d, %I:%M %p")
      end
    end

    def pto_activities
      if object.commentable_type == "PtoRequest" && object.commentable
        pto_activities = object.commentable.activities.order('created_at DESC')
        ActiveModelSerializers::SerializableResource.new(pto_activities, each_serializer: ActivitySerializer::Full, company: object.commentable.user.company) if pto_activities.present?
      end
    end
  end
end
