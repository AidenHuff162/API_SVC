class HrisIntegrationsService::Namely::UpdateSaplingProfileInNamely
  attr_reader :user, :company, :namely_credentials, :namely, :groups, :data_builder, :params_builder, :attributes
  delegate :get_custom_field_value_for_namely_group_type, :get_namely_job_title, :is_namely_credentials?, :get_gender_code, :get_federal_withholding_additional_type_code,
    :get_career_level_code, :get_federal_marital_status_code, :get_type_of_account_code, :find_team, :find_location, :get_home_address,
    :get_namely_profile_image_id, :log_it, :update_namely_profile, to: :helper_service

  def initialize(user, namely, integration, groups, data_builder, params_builder, attributes)
    @user = user
    @company = user.company
    @namely_credentials = integration
    @namely = namely
    @groups = groups
    @data_builder = data_builder
    @params_builder = params_builder
    @attributes = attributes
  end

  def update
    update_profile
  end

  private

  def update_profile
    
    if is_namely_credentials?(@namely_credentials)
      begin
        request_data = @data_builder.build_update_profile_data(@attributes)
        request_params = @params_builder.build_create_profile_params(request_data)
        response = nil
        
        return unless request_params.present?
        
        data = { profiles: [request_params] }

        response = update_namely_profile(data, @namely_credentials, @user) if data[:profiles].first.any?
      
        if response&.ok?
          log_it("Update User Profile in Namely - Success", {request: request_params.inspect, data: data.inspect}, {result: response.inspect}, 200, @company)
        else
          log_it("Update User Profile in Namely - Failure", {request: request_params.inspect, data: data.inspect}, {result: response.inspect}, response.code, @company)
        end
      rescue Exception => e
        log_it("Update User Profile in Namely - Failure", {request: request_params.inspect, data: data.inspect}, {result: e.message}, 500, @company)
      end
    end
  end

  def helper_service
    ::HrisIntegrationsService::Namely::Helper.new
  end
end
