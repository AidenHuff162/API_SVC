class HrisIntegrationsService::Namely::CreateSaplingProfileInNamely
  attr_reader :company, :user, :namely_credentials, :namely, :groups, :data_builder, :params_builder
  delegate :is_namely_credentials?, :send_notifications, :get_career_level_code, :get_gender_code, :get_namely_profile_image_id,
            :get_namely_job_title, :get_custom_field_value_for_namely_group_type, :get_federal_marital_status_code, :get_employee_type,
            :get_federal_withholding_additional_type_code, :get_type_of_account_code, :get_home_address, :log_it, to: :helper_service

  def initialize(user, namely, integration, groups, data_builder, params_builder)
    @user = user
    @company = user.company
    @namely_credentials = integration
    @namely = namely
    @groups = groups
    @data_builder = data_builder
    @params_builder = params_builder
  end

  def create
    create_profile
  end

  private

  def create_profile
    is_create_profile_enabled = @namely_credentials.can_export_new_profile rescue false
    if is_namely_credentials?(@namely_credentials) && is_create_profile_enabled
      begin
        request_data = @data_builder.build_create_profile_data()
        request_params = @params_builder.build_create_profile_params(request_data)
        response = @namely.profiles.create!(request_params)
        profile_id = response.id

        if profile_id.present?
          @user.namely_id = profile_id
          @user.save!
          send_notifications(@user)
          log_it("Create User Profile(#{@user.namely_id}) in Namely - Success", {request: request_params.inspect}, {result: response.inspect}, 201, @company)
        else
          log_it("Create User Profile in Namely - Failure", {request: request_params.inspect}, {message: response.inspect, effected_profile: "#{user.full_name} (#{user.id})"}, 400, @company)
          send_notifications(@user, response.inspect.to_s)
        end
      rescue Exception => e
        response_text = e.inspect
        check_if_email_error = e.message.present? && JSON.parse(e.message)[0].present? && JSON.parse(e.message)[0].include?("#{@user.email || @user.personal_email} is already taken") rescue nil
        if check_if_email_error
          @user.create_active_pending_hire
        end
        if response_text.to_s.include?("for nil:NilClass")
          response_text = "We received an ambiguous response. Please check their API to confirm if the profile was created. The response we received was: #{response_text}"
        end

        @user.reload
        if !@user.namely_id.present?
          message = "*#{@user.company.name}* tried to create a new profile but there was an issue sending *#{@user.full_name}*'s information to *Namely*. We received... *#{response_text}*"
          ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
              IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:human_resource_information_system]))
        end
        log_it("Create User Profile in Namely - Failure", {request: request_params.inspect}, {message: response_text, effected_profile: "#{user.full_name} (#{user.id})"}, 500, @company)
      end
    end
  end

  def helper_service
    ::HrisIntegrationsService::Namely::Helper.new
  end
end
