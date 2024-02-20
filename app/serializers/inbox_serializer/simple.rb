module InboxSerializer
  class Simple < Base
    attributes :email_type, :name, :wrapped_email_type, :is_temporary

    def name
      name = scope[:bulk_onboarding].present? ? object.name.split('---')[-1] : object.name 
      ActionView::Base.full_sanitizer.sanitize(name)
    end

    def wrapped_email_type
      object.map_email_type
    end
  end
end
