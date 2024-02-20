module Api
  module V1
    module Beta
      class SignupController < ::ApiController
        include DeviseTokenAuth::Concerns::SetUserByToken
        include PasswordStrength
        include Signable
        skip_before_action :set_default_subdomain, :set_last_active, :set_current_user_in_model, :set_cache_headers
        before_action :check_subdomain, :check_email, only: :create
        before_action :validate_signup_flag
        
        def create
          @company = Company.new(company_params)
          begin
            @company.save
            start_data_creation
            create_general_logging(@company, 'Company Creation Signup Form', { message: "Company has been created Successfully", time: DateTime.current.utc, params: company_logs_params })
            render json: {temp: create_auth_token, status: 200}
          rescue Exception => e
            create_general_logging(@company, 'Company Creation Signup Form', { error: e.message, time: DateTime.current.utc, params: company_logs_params })
            render json: { error: e.message, status: 422}
          end
        end

        def authorize
          if verify_token
            user_sign_in
            render json: { status: 200}
          else
            render json: { error: 'Validation Token Expired. Login Again', status: 422 }
          end
        end

        def password_strength
          password_strength_checker(params[:password]) if params[:password].present? 
        end

        private

        def company_params
          params.permit(:subdomain, :name).merge(custom_params)
        end

        def user_params
          params.permit(:first_name, :last_name, :password, :email).merge(user_default_params)
        end

        def custom_params
          account_type = get_account_type
          {
            account_type: account_type,
            company_plan: get_company_plan,
            account_state: 'active',
            is_using_custom_table: true,
            created_via_signup_page: true,
            notifications_enabled: (account_type == 6)
          }.merge(get_addons_attributes)
        end

        def start_data_creation
          create_user
          create_salesforce_lead
          create_billing
          start_company_clone
          creat_default_dept_location
        end

        def user_default_params
          {
            role: :account_owner,
            state: :active,
            current_stage: :registered,
            start_date: Date.today,
            is_demo_account_creator: true,
            super_user: is_super_user
          }
        end

      end
    end
  end
end
