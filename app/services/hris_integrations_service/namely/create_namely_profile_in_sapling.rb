class HrisIntegrationsService::Namely::CreateNamelyProfileInSapling
  attr_reader :company, :namely_credentials, :namely, :groups, :parameter_mappings, :profile
  delegate :log_it, :create_user_params, :update_custom_fields, :assign_manager_to_user, to: :helper_service

  def initialize(company, integration, namely, groups, profile)
    @company = company
    @namely_credentials = integration
    @namely = namely
    @groups = groups
    @parameter_mappings = init_parameter_mappings
    @profile = profile
  end

  def create
    create_profile
  end

  private

  def create_profile
    begin
      method_name = "build_parameter_for_" + @company.domain.downcase.gsub('.', '_') rescue nil
      pull_parameters = ::HrisIntegrationsService::Namely::ParamsMapper.new
      additional_company_fields = pull_parameters.public_send(method_name) if pull_parameters.respond_to? method_name
      @parameter_mappings.merge!(additional_company_fields) if additional_company_fields.present?

      data_returned = create_user_params(@profile, @company, @parameter_mappings, @namely, @namely_credentials)
      profile_data = data_returned[:profile_data] 
      custom_fields_data = data_returned[:custom_fields_data] 
      user_params = data_returned[:user_params] 

      provider = user_params["email"] ? 'email' : 'personal_email'
      if !(company.users.where('personal_email ILIKE ?', user_params["personal_email"]).any? || User.where('email ILIKE ?', user_params["email"]).any?)
        user_params.merge!({namely_id: @profile['id'], provider: provider, state: 'active', current_stage: User.current_stages[:registered], created_by_source: 'namely'})
        user_form = UserForm.new(user_params)
        user_form[:company_id] = @company.id
        user_form.save!
        user = user_form&.user
        user.profile.update!(profile_data)
        user.profile.updating_integration = @namely_credentials
        assign_manager_to_user(user, @profile, @company)
        update_custom_fields(custom_fields_data, user, @company, @profile, @namely_credentials, @namely)
        log_it("Create user in Sapling (#{user.namely_id}) from Namely - Success", {request: "GET Profile"}, {result: user.inspect}, 200, @company)
      end
    rescue Exception => e
      log_it("Create user in Sapling (#{@profile['id']}) from Namely - Failure", {request: "GET Profile"}, {result: e.message}, 500, @company)
    end
  end

  def init_parameter_mappings
    params_mapping = ::HrisIntegrationsService::Namely::ParamsMapper.new.build_v2_parameter_mapping
  end

  def helper_service
    ::HrisIntegrationsService::Namely::Helper.new
  end

end


