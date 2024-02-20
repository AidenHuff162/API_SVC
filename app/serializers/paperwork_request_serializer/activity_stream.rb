module PaperworkRequestSerializer
  class ActivityStream < ActiveModel::Serializer
    attributes :id, :user_id, :hellosign_signature_request_id, :title, :user_name, :type,
               :due_date, :created_at

    def user_name
      object.user.preferred_name || object.user.first_name
    end

    def title
      object.document.title
    end

    def type
      'counter_sign'
    end

    def due_date
      Date.today
    end
  end
end
