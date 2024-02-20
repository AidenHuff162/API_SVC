module UserSerializer
  class Mention < ActiveModel::Serializer
    attributes :id, :email, :picture, :tag, :first_name, :last_name, :full_name, :preferred_name, :preferred_full_name, :display_name

    def tag
      ["#{object.display_name}", "#{object.id}"].compact.reject(&:blank?) * ':'
    end

    def email
      (((object.start_date.present? && object.start_date > Date.today) || !object.email.present?) && object.personal_email.present?) ? object.personal_email : object.email
    end
  end
end
