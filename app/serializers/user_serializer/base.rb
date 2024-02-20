module UserSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :full_name, :preferred_name, :preferred_full_name, 
               :is_reset_password_token_set, :is_password_set, :about_you, :provider, :display_name_format, 
               :title, :location_name, :seen_profile_setup, :seen_documents_v2, :ui_switcher

    def is_reset_password_token_set
      object.reset_password_token.present?
    end

    def is_password_set
      !object.encrypted_password.to_s.empty?
    end

    def about_you
      object.get_cached_about_you
    end

    def display_name_format
      object.company.display_name_format
    end

  end
end
