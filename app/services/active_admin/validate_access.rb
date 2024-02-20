module ActiveAdmin
  class ValidateAccess
    attr_reader :access_token, :current_admin_user

    def initialize access_token, current_admin_user
      @access_token = access_token
      @current_admin_user = current_admin_user
    end

    def check_validity?
      return false if !@current_admin_user.present?
      return false if !@access_token.present?
      is_valid_admin?  
    end

    private

    def is_valid_admin?
      if @access_token.present?
        if access_token_belongs_to_current_admin?
          true
        else
          false
        end
      else
        false
      end
    end

    def access_token_belongs_to_current_admin?
      @current_admin_user.present? && (@current_admin_user.access_token == @access_token) && has_same_decrypted_access_token?
    end

    def has_same_decrypted_access_token?
      begin
        crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base)
        decrypted_token_from_params = crypt.decrypt_and_verify(@access_token)
        decrypted_token_form_db = crypt.decrypt_and_verify(@current_admin_user.access_token)
        decrypted_token_form_db == decrypted_token_from_params
      rescue Exception => e
        false
      end
    end


  end
end