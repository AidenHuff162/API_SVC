module Api
  module V1
    module Auth
      class PasswordsController < ::DeviseTokenAuth::PasswordsController
        before_action :append_redirection_url_param, only: :edit
        before_action :validate_redirect_url_param, only: [:create, :edit]
        skip_after_action :update_auth_header, only: [:create, :edit]

         # this action is responsible for generating password reset tokens and sending emails
        def create

          return render json: { errors: [I18n.t('errors.invalid_recaptcha')] } if !Rails.env.test? && !verify_recaptcha

          unless resource_params[:email] || resource_params[:personal_email]
            return render_create_error_missing_email
          end

          @redirect_url = params[:redirect_url]

          @redirect_url ||= DeviseTokenAuth.default_password_reset_url

          unless @redirect_url
            return render_create_error_missing_redirect_url
          end

          if DeviseTokenAuth.redirect_whitelist
            unless DeviseTokenAuth::Url.whitelisted?(@redirect_url)
              return render_create_error_not_allowed_redirect_url
            end
          end

          if resource_class.case_insensitive_keys.include?(:email) || resource_class.case_insensitive_keys.include?(:personal_email)
            @email = resource_params[:email].downcase if resource_params[:email]
            @email = resource_params[:personal_email].downcase if resource_params[:personal_email]
          else
            @email = resource_params[:email] || resource_params[:personal_email]
          end

          q = "uid = ? AND provider='email'"
          q_p = "uid = ? AND provider='personal_email'"

          if ActiveRecord::Base.connection.adapter_name.downcase.starts_with? 'mysql'
            q = "BINARY uid = ? AND provider='email'"
            q_p = "BINARY uid = ? AND provider='personal_email'"
          end
          company_id = Company.find_by(subdomain:URI.parse(@redirect_url).host.split('.').first)&.id
          @resource = resource_class.where("(email = :email_value OR personal_email = :email_value) AND company_id = :company_id AND state = 'active'", email_value: @email, company_id: company_id).where.not("current_stage IN (?)", [User.current_stages[:departed], User.current_stages[:incomplete]]).first
          @errors = nil
          @error_status = 400

          if @resource && @resource.active?
            yield @resource if block_given?
            @resource.send_reset_password_instructions({
              email: @email,
              redirect_url: @redirect_url,
              client_config: params[:config_name]
            })
            if @resource.errors.empty?
              if ((@resource.super_user.blank? && @resource.company.otp_required_for_login.present?) || @resource.otp_required_for_login?)
                Users::ManageTfaJob.perform_later(@resource.company_id, @resource.id, false)
              end
              
            else
              @errors = @resource.errors
            end
          end

          if @errors
            return render_create_error
          else
            render json: { errors: [I18n.t('reset.reset_password_message')] }, status: 200
            return
          end
        end

        # this is where users arrive after visiting the password reset confirmation link
        def edit
          @resource = resource_class.with_reset_password_token(resource_params[:reset_password_token])

          if @resource && @resource.reset_password_period_valid?
            token = @resource.create_token unless require_client_password_reset_token?

            # ensure that user is confirmed
            @resource.skip_confirmation! if confirmable_enabled? && !@resource.confirmed_at
            # allow user to change password once without current_password
            @resource.allow_password_change = true if recoverable_enabled?

            @resource.save!

            yield @resource if block_given?

            if require_client_password_reset_token?
              redirect_to DeviseTokenAuth::Url.generate(@redirect_url, reset_password_token: resource_params[:reset_password_token])
            else
              redirect_header_options = { reset_password: true }
              redirect_headers = build_redirect_headers(token.token,
                                                        token.client,
                                                        redirect_header_options)
              redirect_to(@resource.build_auth_url(@redirect_url,
                                                   redirect_headers))
            end
          else
            render_edit_error
          end
        end

        # this action is responsible for updating password
        def update
          if require_client_password_reset_token? && resource_params[:reset_password_token]
            @resource = resource_class.with_reset_password_token(resource_params[:reset_password_token])
            return render_update_error_unauthorized unless @resource

            @token = @resource.create_token
          else
            @resource = set_user_by_token
          end

          unless @resource
            return render_update_error_unauthorized
          end
          unless @resource.provider == 'email' || @resource.provider == 'personal_email'
            return render_update_error_password_not_required
          end

          unless password_resource_params[:password] and password_resource_params[:password_confirmation]
            return render_update_error_missing_password
          end

          if @resource.send(resource_update_method, password_resource_params)
            if ((@resource.super_user.blank? && @resource.company.otp_required_for_login.present?) || @resource.otp_required_for_login?)
              Users::ManageTfaJob.perform_later(@resource.company_id, @resource.id, false)
            end
            
            @resource.allow_password_change = false
            if current_user.current_stage == 'invited'
              current_user.preboarding!
              PushEventJob.perform_later('preboarding-started', current_user, {
                employee_id: current_user.id,
                employee_name: current_user.first_name + ' ' + current_user.last_name,
                employee_email: current_user.email
              })
              SlackNotificationJob.perform_later(current_user.company_id, {
                username: current_user.full_name,
                text: "Employee *#{current_user.first_name} #{current_user.last_name}* preboarding has been started."
              })
            end

            UserMailer.change_password_email(current_user).deliver_now! if params[:send_email] == true
            yield @resource if block_given?
            update_sign_in_count
            return render_update_success
          else
            return render_update_error
          end
        end

        def render_edit_error
          redirect_to root_path
        end

        protected

        def append_redirection_url_param
          user = resource_class.with_reset_password_token(resource_params[:reset_password_token])
          if user.present?
            if user.inactive?
              if Rails.env.production?
                redirect_to "https://#{user.company.domain}/#/login"
              else
                redirect_to "http://#{user.company.domain}/#/login"
              end
            else
              if Rails.env.production?
                params[:redirect_url] = "https://#{user.company.domain}/#/reset_password"
              else
                params[:redirect_url] = "http://#{user.company.domain}/#/reset_password"
              end
            end
          else
            if params['cid'].present?
              company = Company.find(params['cid'])
              redirect_to URI.parse("http://#{company.domain}").to_s
            else
              render file: 'public/invitation_expired.html'
            end
          end
        end

        def resource_errors
          @resource.errors.to_hash.merge(full_messages: @resource.errors.full_messages)
        end

        def verify_recaptcha
          response = HTTParty.post("https://www.google.com/recaptcha/api/siteverify?secret=#{ENV['RECAPTCHA_SECRET_KEY']}&response=#{params[:recaptcha_response]}")
          return JSON.parse(response.body)['success'] || authorize_account_owner
        end

        def render_create_error
          render json: { errors: [Errors::NotFound.new(@errors[0]).error] }, status: :not_found
        end

        def render_update_error
          errors = resource_errors
          if errors[:full_messages].first.include? "Password is too short"
            render json: { errors: [Errors::PasswordShort.new(errors[:full_messages].first)] }, status: 457
          elsif errors[:full_messages].first.include? "Password must have a minimum of eight characters at least one number and one special character."
            render json: { errors: [Errors::PasswordComplexity.new(errors[:full_messages].first)] }, status: 457
          else
            render json: { errors: [Errors::NotFound.new(errors[0]).error] }, status: :not_found
          end
        end

        def render_update_success
          render json: {
            success: true,
            data: {current_stage: current_user.current_stage}.as_json,
            message: I18n.t('devise_token_auth.passwords.successfully_updated')
          }
        end

        private
        def resource_params
          params.permit(:email, :personal_email, :password, :password_confirmation, :current_password, :reset_password_token)
        end

        def password_resource_params
          params.permit(*params_for_resource(:account_update))
        end

        def authorize_account_owner
          ['account_owner', 'admin'].include?(current_user.role) && current_user.company.users.where(state: 'active').where("email = :email_value OR personal_email = :email_value", email_value: params[:password][:email])
        end

        def update_sign_in_count
          current_user.update_column(:sign_in_count, (current_user.sign_in_count || 0) + 1)
        end

      end
    end
  end
end
