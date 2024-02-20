class HrisIntegrationsService::Namely::UpdateNamelyProfileInSapling
  attr_reader :company, :namely_credentials, :namely, :groups, :parameter_mappings, :profile
  delegate :log_it, :create_user_params, :can_integrate_profile?, :assign_manager_to_user, :update_custom_fields, to: :helper_service

  def initialize(company, integration, namely, groups, profile)
    @company = company
    @namely_credentials = integration
    @namely = namely
    @groups = groups
    @parameter_mappings = init_parameter_mappings
    @profile = profile
  end

  def update
    update_profile
  end

  private

  def update_profile
    begin
      user = @company.users.find_by(namely_id: @profile['id'])
      return if !can_integrate_profile?(@namely_credentials, user)
      method_name = "build_parameter_for_" + @company.domain.downcase&.gsub('.', '_') rescue nil
      pull_parameters = ::HrisIntegrationsService::Namely::ParamsMapper.new
      additional_company_fields = pull_parameters.public_send(method_name) if pull_parameters.respond_to? method_name
      @parameter_mappings.merge!(additional_company_fields) if additional_company_fields.present?

      data_returned = create_user_params(@profile, @company, @parameter_mappings, @namely, @namely_credentials)
      profile_data = data_returned[:profile_data] 
      custom_fields_data = data_returned[:custom_fields_data]
      user_params = data_returned[:user_params]
      user_params_keys = user_params.keys
      temp_user = user.attributes
      temp_profile = user.profile&.attributes

      if user.present?
        original_user = user.dup
        user.update!(user_params)
        user.profile.update!(profile_data)
        user.profile.updating_integration = @namely_credentials
        user.reload
        assign_manager_to_user(user, @profile, @company)
        old_custom_field = update_custom_fields(custom_fields_data, user, @company, @profile, @namely_credentials, @namely)
        user_params_keys.append(user.profile&.attributes&.keys)
        user_params_keys.delete(:updated_from)
        user_params_keys.delete(:updating_integration)
        user_params_keys.delete(:company_id)

        log_it("Update user in Sapling (#{@profile['id']}) from Namely - Success", {request: "GET Profile"}, {result: @profile.inspect}, 200, @company)
        ::Inbox::UpdateScheduledEmail.new.update_scheduled_user_emails(user, original_user)
        WebhookEvents::ManageWebhookPayloadJob.perform_async(company.id, {default_data_change: user_params_keys&.flatten, user: user.id, temp_user: temp_user, webhook_custom_field_data: old_custom_field, temp_profile: temp_profile})
      end
    rescue Exception => e
      log_it("Update user in Sapling (#{@profile['id']}) from Namely - Failure", {request: "GET Profile"}, {result: e.message}, 500, @company)
    end
  end

  def init_parameter_mappings
    params_mapping = ::HrisIntegrationsService::Namely::ParamsMapper.new.build_v2_parameter_mapping
  end

  def helper_service
    ::HrisIntegrationsService::Namely::Helper.new
  end
end
