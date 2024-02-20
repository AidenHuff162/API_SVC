class HrisIntegrationsService::Bamboo::UpdateBambooFromSapling
  attr_reader :single_dimension_service, :tabular_data_service, :user

  delegate :create_bamboo_employee, :update_bamboo_employee, to: :employee

  def initialize(user, create)
    user = User.find_by_id(user.id)
    return if user.bamboo_id.present? && create

    @user = user

    if user.company.id == 32
      @single_dimension_service = HrisIntegrationsService::Bamboo::Scality::ManageBambooSingleDimensionData.new user
    elsif user.company.id == 34
      @single_dimension_service = HrisIntegrationsService::Bamboo::Addepar::ManageBambooSingleDimensionData.new user
    elsif user.company.id == 64
      @single_dimension_service = HrisIntegrationsService::Bamboo::Fivestars::ManageBambooSingleDimensionData.new user
    elsif user.company.id == 185
      @single_dimension_service = HrisIntegrationsService::Bamboo::Doordash::ManageBambooSingleDimensionData.new user
    elsif user.company.id == 20
      @single_dimension_service = HrisIntegrationsService::Bamboo::DigitalOcean::ManageBambooSingleDimensionData.new user
    elsif user.company.id == 288
      @single_dimension_service = HrisIntegrationsService::Bamboo::Forward::ManageBambooSingleDimensionData.new user
    elsif user.company.id == 363
      @single_dimension_service = HrisIntegrationsService::Bamboo::Recursion::ManageBambooSingleDimensionData.new user
    else
      @single_dimension_service = HrisIntegrationsService::Bamboo::ManageBambooSingleDimensionData.new user
    end

    if user.company.id == 34
      @tabular_data_service = HrisIntegrationsService::Bamboo::Addepar::ManageBambooTabularData.new user
    elsif user.company.id == 64
      @tabular_data_service = HrisIntegrationsService::Bamboo::Fivestars::ManageBambooTabularData.new user
    elsif user.company.id == 185
      @tabular_data_service = HrisIntegrationsService::Bamboo::Doordash::ManageBambooTabularData.new user
    elsif user.company.id == 191
      @tabular_data_service = HrisIntegrationsService::Bamboo::Zapier::ManageBambooTabularData.new user
    elsif user.company.id == 288
      @tabular_data_service = HrisIntegrationsService::Bamboo::Forward::ManageBambooTabularData.new user
    else
      @tabular_data_service = HrisIntegrationsService::Bamboo::ManageBambooTabularData.new user
    end
  end

  def create(is_send_documents = false)
    return if !user.present? && (user.present? && user.bamboo_id.present?)
    create_bamboo_user(is_send_documents)
  end

  def update(field_name)
    return if !user.present? || (user.present? && !user.bamboo_id.present?)
    update_bamboo_user(field_name)
  end

  private

  def employee
    HrisIntegrationsService::Bamboo::Employee.new user.company
  end

  def create_bamboo_user(is_send_documents = false)
    bamboo_id = user.bamboo_id
    user_hash = @single_dimension_service.prepare_user_data
    custom_hash = @single_dimension_service.prepare_custom_data
    hash = user_hash.merge!(custom_hash)
    
    if @user.company.id == 288
      profile_hash = @single_dimension_service.prepare_profile_data
      hash = hash.merge!(profile_hash) 
    end

    hash.delete(:ssn) if should_exclude_ssn_field?(hash)
    bamboo_id = create_bamboo_employee(user, hash)
    
    if bamboo_id.present?
      user.update_column(:bamboo_id, bamboo_id)
      user.reload
      send_notifications(user)

      update_user_profile_picture
      update_tabular_data

      if is_send_documents.present?
        upload_document
      end
    end
  end

  def upload_document
    documents = user.paperwork_requests.where("((co_signer_id IS NOT NULL AND state = 'all_signed') OR (co_signer_id IS NULL AND state = 'signed')) AND signed_document IS NOT NULL")
    if documents && documents.present?
      documents.all.each do |papweqork_request|
        ::HrisIntegrations::Bamboo::UpdateBambooDocumentsFromSaplingJob.perform_later(papweqork_request, papweqork_request.user, 'paperwork_requests')
      end
    end

    documents =  user.user_document_connections.where(state: 'completed')
    if documents && documents.present?
      documents.all.each do |request|
        ::HrisIntegrations::Bamboo::UpdateBambooDocumentsFromSaplingJob.perform_later(request, request.user, 'document_upload_request_file')
      end
    end
  end

  def update_user_profile_picture
    photo = HrisIntegrationsService::Bamboo::Photo.new user.company
    photo.create(user)
  end

  def update_tabular_data
    @tabular_data_service.update_tabular_data
  end

  def update_selected_tabular_data(field_name)
    @tabular_data_service.update_selected_tabular_data(field_name)
  end

  def update_selected_single_dimension_data(field_name)
    param = {}

    if field_name == 'Offboarded'
      param[:status] = 'inactive'
    else
      param = @single_dimension_service.get_single_dimension_data(field_name)
    end

    param.delete(:ssn) if field_name.try(:downcase) == 'social security number' && should_exclude_ssn_field?(param)
    update_bamboo_employee(user, param) if param.present?
  end

  def update_bamboo_user(field_name)
    if field_name == 'Profile Photo'
      update_user_profile_picture
    else
      update_selected_tabular_data(field_name)
      update_selected_single_dimension_data(field_name)
    end
  end

  def send_notifications(user)
    message = I18n.t("history_notifications.hris_sent", name: user.full_name, hris: "BambooHR")
    History.create_history({
      company: user.company,
      description: message,
      attached_users: [user.id],
      created_by: History.created_bies[:system],
      integration_type: History.integration_types[:bamboo],
      event_type: History.event_types[:integration]
    })

    SlackNotificationJob.perform_later(user.company.id, {
      username: user.full_name,
      text: message
    })
  end

  def should_exclude_ssn_field?(params)
    !params[:ssn]&.match(/^(?!666|000|9\d{2})\d{3}-(?!00)\d{2}-(?!0{4})\d{4}$/) rescue false
  end
end
