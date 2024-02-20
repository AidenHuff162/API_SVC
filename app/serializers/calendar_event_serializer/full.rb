module CalendarEventSerializer
  class Full < UpdatesPage
    attributes :id, :event_end_date, :color, :user_name, :user_display_name, :pto_display_detail

    def pto_display_detail
      object.eventable_type == 'PtoRequest' ? object.eventable.pto_policy.display_detail : nil
    end

    def user_name
      if object.eventable_type == "PtoRequest"
        object.eventable.user.display_name
      else
        nil
      end
    end

    def user_display_name
      if object.eventable_type == "PtoRequest"
        object.eventable.user.company.global_display_name(object.eventable.user, object.eventable.user.company.display_name_format)
      else
        nil
      end
    end
  end
end
