module CalendarFeedSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :feed_url, :feed_type, :feed_id, :user_id
  end
end
