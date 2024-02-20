module AdminUsers
  class PasswordsController < ActiveAdmin::Devise::PasswordsController
    include ::ActiveAdmin::Devise::Controller

    def update
      self.resource = resource_class.reset_password_by_token(resource_params)
      @admin_user = AdminUser.where(email: self.resource.email).first if self.resource.present?         
      if @admin_user.present? && password_equals?
        @admin_user.update_column(:encrypted_password, BCrypt::Password.create(params[:admin_user][:password]))   
        params[:password] = encrypt_password
        if @admin_user.otp_required_for_login                    
          params[:redirect_id] = 0          
          render 'admin_users/sessions/qr_template'
        else
          resource.after_database_authentication
          sign_in(resource_name, resource)
          respond_with resource, location: after_resetting_password_path_for(resource)
        end
      else
        redirect_back(fallback_location: root_path)
      end
    end
    
    protected
    def after_resetting_password_path_for(resource)
      new_session_path(resource_name)
    end

    private
    def password_equals?
      return false unless params[:admin_user][:password] == params[:admin_user][:password_confirmation]
      return true
    end

    def encrypt_password
      crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base)
      password = crypt.encrypt_and_sign(params[:admin_user][:password])
    end    
  end
end
