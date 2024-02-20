module PtoRequestSerializer
  class Email < ActiveModel::Serializer
    attributes :id, :user_full_name, :user_first_name, :user_image, :user_initials, :date_range, :type, :length, :leftover, :comment, :company_logo, :policy_name

    def user_full_name
      object.user.display_name
    end

    def user_first_name
      object.user.preferred_name || object.user.first_name
    end

    def user_image
      object.user.picture
    end

    def user_initials
      "#{object.user.preferred_full_name[0,1] } #{object.user.last_name[0,1]}"
    end

    def date_range
      object.get_date_range
    end

    def type
      object.pto_policy.try(:policy_type).try(:titleize)
    end

    def policy_name
      object.pto_policy.try(:name)
    end

    def length
      object.get_request_length
    end

    def leftover
      object.pto_policy.unlimited_policy ? nil : object.calculate_carryover_balance
    end

    def comment
      object.email_options.present? && object.email_options["comment_id"].present? ? Comment.find_by(id: object.email_options["comment_id"]).try(:get_token_replaced_description) : object.comments.order('id desc').take.try(:get_token_replaced_description)
    end

    def company_logo
      object.pto_policy&.company&.logo
    end
  end
end
