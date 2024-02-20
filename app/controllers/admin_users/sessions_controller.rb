module AdminUsers
  class SessionsController < ActiveAdmin::Devise::SessionsController
    layout 'active_admin_logged_out'
    helper ::ActiveAdmin::ViewHelpers
    before_action :configure_permitted_parameters
    include SetAdminAccessToken
    before_action :check_if_logged_in?, only: [:change_password_form , :update_password]

    def create
      if params[:redirect_id].present? && params[:redirect_id] == "1"
        redirect_to_login_page
        return        
      end
      email = sign_in_params[:email].present? ? sign_in_params[:email] : params[:user_email]
      admin_user = AdminUser.find_for_authentication(email: email) if email.present?
      if admin_user.present?
        if admin_user.active?
          crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base)
          password = sign_in_params[:password].present? ? sign_in_params[:password] : crypt.decrypt_and_verify(params[:password])
          if admin_user.valid_password?(password)
            @admin_user = admin_user
            if admin_user.otp_required_for_login?
              if !sign_in_params[:otp_attempt].present?
                @sign_in_params = sign_in_params
                render :otp_authentication
              else
                set_access_token_on_front_end(@admin_user)
                @admin_user.active_admin_loggings.create!(action: "Admin user #{@admin_user.email} logged in.")
                # warden.set_user(@admin_user, scope: resource_name)
                super
              end
            else
              set_access_token_on_front_end(@admin_user)
              @admin_user.active_admin_loggings.create!(action: "Admin user #{@admin_user.email} logged in.")
              super
            end
          else
            @admin_user = admin_user || AdminUser.new
            flash[:notice] = "Invalid password!"
            redirect_to action: :new
          end
        else
          @admin_user = admin_user || AdminUser.new
          flash[:notice] = "Inactive user. Please activate it to continue!"
          redirect_to action: :new
        end
      else
        @admin_user = admin_user || AdminUser.new
        flash[:notice] = "Invalid email!"
        redirect_to action: :new
      end
    end

    def after_sign_in_path_for(resource)
      admin_dashboard_path
    end

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_in, keys: [:email, :password, :otp_attempt])
    end

    def destroy
      current_admin_user.update_column(:access_token, nil)
      cookies.delete :admin_access_token
      super
    end
    
    def change_password_form   
      begin
        user_email = JsonWebToken.decode(params[:token])['email']
        @user = AdminUser.where(:email=>user_email,:email_verification_token=>params[:token]).first
        @user.update_column(:email_verification_token,nil)
      rescue Exception => e
        raise_not_found
      end                
    end

    def update_password
      @admin_user = AdminUser.where(:email=>params[:admin_user][:email]).first      
      if @admin_user.present? && password_equals?                
        @admin_user.update_column(:encrypted_password,BCrypt::Password.create(params[:admin_user][:password]))   
        render 'admin_users/sessions/qr_template'
      else
        redirect_back(fallback_location: root_path)
      end
    end

    def check_if_logged_in?
      raise_not_found if admin_user_signed_in?
    end

    def password_equals?
      return false unless params[:admin_user][:password] == params[:admin_user][:password_confirmation]
      return true
    end

    private

    def redirect_to_login_page
      AdminUser.where(:email=>params[:user_email]).first.update_column(:first_login,FALSE)
      redirect_to action: :new            
    end
  end
end
