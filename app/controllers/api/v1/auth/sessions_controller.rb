module Api
  module V1
    module Auth
      class SessionsController < ::DeviseTokenAuth::SessionsController
        before_action :configure_permitted_parameters
        before_action :require_company!, only: :create

        def create
      # Check
          field = (resource_params.keys.map(&:to_sym) & resource_class.authentication_keys).first
          @resource = nil
          if field
            q_value = resource_params[field]

            if resource_class.case_insensitive_keys.include?(field)
              q_value.downcase!
            end

            q = "#{field.to_s} = ? AND provider='email'"
            if ActiveRecord::Base.connection.adapter_name.downcase.starts_with? 'mysql'
              q = "BINARY " + q
            end

            @resource = populate_resource(field,q,q_value)
          end

          if @resource and valid_params?(field, q_value) and (!@resource.respond_to?(:active_for_authentication?) or @resource.active_for_authentication?)
            if resource_params[:otp_attempt].present?
              begin
                crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base)
                params[:password] = crypt.decrypt_and_verify(resource_params[:password]) 
              rescue Exception => e
              end
            end
            
            valid_password = @resource.valid_password?(resource_params[:password])
            if (@resource.respond_to?(:valid_for_authentication?) && !@resource.valid_for_authentication? { valid_password }) || !valid_password
              render_create_error_bad_credentials(remaining_attempts)
              return
            end
            
            if @resource.start_date.present? && @resource.start_date <= Date.today && current_company.login_type == 'only_sso'
              render_create_error_sso_only
              return
            end

            if two_factor_auth_enabled? && !resource_params[:otp_attempt].present?
              @resource_params = resource_params
              render_otp_authentication
            elsif two_factor_auth_enabled? && resource_params[:otp_attempt].present? && resource_params[:otp_attempt] != @resource.current_otp.to_i
              render_invalid_otp_code
            else
              @token = @resource.create_token
              @resource.last_logged_in_email = resource_params[:email]
              @resource.show_qr_code = false
              @resource.save
              sign_in(:user, @resource, store: false, bypass: false)
              yield @resource if block_given?

              render_create_success
            end
            
          elsif @resource and not (!@resource.respond_to?(:active_for_authentication?) or @resource.active_for_authentication?)
            render_create_error_not_confirmed
          elsif @resource and valid_params?(field, q_value) and !@resource.valid_password?(resource_params[:password])
            render_create_error_bad_password
          else
            render_create_error_bad_credentials(remaining_attempts)
          end
        end

        def new
          redirect_to root_path
        end

        protected
          def configure_permitted_parameters
            devise_parameter_sanitizer.permit(:sign_in, keys: [:email, :password, :otp_attempt])
          end

          def render_otp_authentication
            issuer = "#{current_company.name} Login"
            label = [issuer, resource_params[:email]].join(": ")
            code = @resource.show_qr_code ? @resource.otp_provisioning_uri(label, issuer: issuer) : nil
            crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base)
            render json: {email: resource_params[:email], password: crypt.encrypt_and_sign(resource_params[:password]), show_qr_code: @resource.show_qr_code, url: encrypt_url(code), render_otp: true}
          end

          def render_create_success
            if current_user.role == 'account_owner' || (PermissionService.new.fetch_accessable_custom_field_sections(current_company, current_user, @resource)).include?(0)
              render json: @resource, serializer: UserSerializer::Full, include: '**'
            else
              render json: @resource, serializer: UserSerializer::Permitted, scope: { current_user: current_user }, include: '**'
            end
          end

          def render_create_error_sso_only
            render json: { success: false, errors: "sso_only", signedIn: false }, status: 455
          end

          def render_create_error_bad_credentials(tries_left = 1)
            msg = ""
            unless tries_left == -9 || tries_left > 0
              msg = I18n.t("log_in.locked_msg")
            end
            render json: { errors: [::Errors::InvalidEmailPassword.error] }, status: 455
          end

          def render_create_error_bad_password
            render json: { errors: [::Errors::InvalidEmailPassword.error] }, status: 455
          end

          def render_invalid_otp_code
            msg = I18n.t("log_in.authentication_error")
            render json: { errors: [{title: msg}] }, status: 455
          end

          def render_create_error_not_confirmed
            msg = I18n.t("log_in.locked_msg")
            render json: { success: false, errors: [::Errors::AccountLocked.error] }, status: 458
          end

        private
          def resource_params
            params.permit(*params_for_resource(:sign_in))
          end

          def populate_resource(field,q,q_value)
            q_p = "#{field.to_s} = ? AND provider= ? "
            rel = resource_class.where(company_id: current_company.id).where.not("state = 'inactive' OR current_stage = ?", User.current_stages[:departed])

            resource = rel.where(q, q_value).first
            resource = rel.where(q_p, q_value, 'personal_email').first if !resource
            resource = rel.where(q.sub("email", "personal_email"), q_value).first || rel.where(q.gsub("email", "personal_email"), q_value).first if !resource
            resource
          end

          def remaining_attempts
            if @resource
              max_attempts = @resource.role == 'employee' ? Sapling::Application::LOGIN_ATTEMPTS[:user] : Sapling::Application::LOGIN_ATTEMPTS[:admin]
              max_attempts - @resource.failed_attempts
            else
              -9
            end
          end

          def current_company
            @current_company ||= request.env['CURRENT_COMPANY']
          end

          def require_company!
            raise ActiveRecord::RecordNotFound unless current_company
          end

          def two_factor_auth_enabled?
            current_company.present? && ((@resource.super_user.blank? && current_company.otp_required_for_login.present?) || (@resource.super_user.present? && @resource.otp_required_for_login?)) && current_company.login_type != 'only_sso'
          end

          def encrypt_url data
            if data.present?
              key = ENV["TWO_FACTOR_URL_KEY"].scan(/../).collect{ |x| x.hex }.pack('c*')
              iv = ENV["TWO_FACTOR_URL_KEY_IV"].scan(/../).collect{ |x| x.hex }.pack('c*')

              aes = OpenSSL::Cipher::Cipher.new('aes-128-cbc')
              aes.encrypt
              aes.key = key
              aes.iv = iv
              enc = aes.update(data)
              enc << aes.final

              return Base64.encode64(enc)
            end
          end
      end
    end
  end
end
