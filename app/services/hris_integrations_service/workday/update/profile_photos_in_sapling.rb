class HrisIntegrationsService::Workday::Update::ProfilePhotosInSapling < ApplicationService
  include HrisIntegrationsService::Workday::Logs
  attr_reader :user, :company, :workday_id_type, :workday_id, :operation_name

  delegate :prepare_request, to: :web_service

  def initialize(user)
    @user = user
    @company = user.company # for loggings
    @workday_id = user.workday_id
    @workday_id_type = user.workday_id_type
    @operation_name = 'get_worker_photos'
  end

  def call
    get_worker_photo
  end

  private

  def get_worker_photo
    response = nil
    begin
      response = get_worker_photos_response
      user.save_profile_image(get_photo(response&.body || {}))
    rescue Exception => @error
      replace_logging_content(response&.body, :response_photo, :file)
      error_log("Unable to update profile photo of user with id: (#{user.id}) in Sapling",
                { response: response&.body }, {params: api_request_params})
    end
  end

  def api_request_params
    { user_id: user.id, workday_id_type: workday_id_type, workday_id: workday_id }
  end

  def get_worker_photos_response
    prepare_request(operation_name, get_worker_photos_params)
  end

  def get_worker_photos_params
    params = { workday_id: workday_id, workday_id_type: workday_id_type }
    request_params_builder.call(operation_name, params)
  end

  def helper_service
    HrisIntegrationsService::Workday::Helper.new
  end

  def web_service
    HrisIntegrationsService::Workday::WebService.new(company.id)
  end

  def request_params_builder
    HrisIntegrationsService::Workday::ParamsBuilder::Workday
  end

  def get_photo(response_body)
    response_body.dig(:get_worker_photos_response, :response_data, :worker_photo, :worker_photo_data, :file)
  end

end
