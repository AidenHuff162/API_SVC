module ActiveAdmin
  class SetEncryptedAccessToken

    attr_reader :admin_user_id

    def initialize user_id
      @admin_user = AdminUser.find(user_id)
    end

    def perform
      set_access_token
    end

    private

    def set_access_token
      @admin_user.update_column(:access_token, get_encrypted_access_token)
    end

    def get_encrypted_access_token
      token = SecureRandom.hex
      crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base)
      crypt.encrypt_and_sign(token)
    end

  end
end