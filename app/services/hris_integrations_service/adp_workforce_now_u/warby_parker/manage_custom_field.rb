class HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ManageCustomField
  attr_reader :company, :user, :adp_wfn_api, :enviornment, :params_builder_service, :data_builder_service, :certificate, :access_token

  delegate :create_loggings, to: :helper_service

  def initialize(company, user, adp_wfn_api, enviornment, params_builder_service, data_builder_service, certificate, access_token)
    @company = company
    @user = user
    @adp_wfn_api = adp_wfn_api
    @enviornment = enviornment
    @params_builder_service = params_builder_service
    @data_builder_service = data_builder_service
    @certificate = certificate
    @access_token = access_token
  end

  def update_adp_from_sapling(field_name = nil, field_id = nil, field_value = nil)
    return unless field_name.present? || field_id.present?
    if field_id.blank? && field_name.present?
      field_name = field_name.downcase
      case field_name
      when 'people manager?', 'retail district', 'dayforce user?', 'division', 'personal pronoun', 'gender identity', 'sub department'
        change_custom_field(access_token, certificate, field_name)
      end
    end
  end

  private

  def change_custom_field(access_token, certificate, field_name)
    field_value = user.get_custom_field_value_text(field_name).to_s
    
    data = data_builder_service.build_change_string_custom_field_data(user, field_name, field_value)
    params = params_builder_service.build_change_string_custom_field_params(data)

    begin
      response = events_service.change_string_custom_field(params, access_token, certificate)
      
      log(response.status, "Update Profile in ADP - #{field_name.upcase} - SUCCESS", { data: data, params: params, response: JSON.parse(response.body) }, params)
    rescue Exception => e
      log(500, "Update Profile in ADP - #{field_name.upcase} - ERROR", { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
    end
  end

  def helper_service
    HrisIntegrationsService::AdpWorkforceNowU::Helper.new
  end
  
  def events_service
    HrisIntegrationsService::AdpWorkforceNowU::Events.new
  end

  def log(status, action, result, request = nil)
    create_loggings(company, "ADP Workforce Now - #{enviornment}", status, action, result, request)
  end
end