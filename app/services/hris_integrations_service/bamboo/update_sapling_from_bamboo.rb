class HrisIntegrationsService::Bamboo::UpdateSaplingFromBamboo
  attr_reader :single_dimension_service, :tabular_data_service, :company, :is_update_all

  delegate :fetch_bamboo_employees, :fetch_updated_bamboo_employees, :find_bamboo_employee, to: :employee

  def initialize(company, is_update_all = false)
    @company = company
    @is_update_all = is_update_all

    if company.id == 32
      @single_dimension_service = ::HrisIntegrationsService::Bamboo::Scality::ManageSaplingSingleDimensionData.new company
    elsif company.id == 34
      @single_dimension_service = ::HrisIntegrationsService::Bamboo::Addepar::ManageSaplingSingleDimensionData.new company
    elsif company.id == 64
      @single_dimension_service = ::HrisIntegrationsService::Bamboo::Fivestars::ManageSaplingSingleDimensionData.new company
    elsif company.id == 185
      @single_dimension_service = ::HrisIntegrationsService::Bamboo::Doordash::ManageSaplingSingleDimensionData.new company
    elsif company.id == 20
      @single_dimension_service = ::HrisIntegrationsService::Bamboo::DigitalOcean::ManageSaplingSingleDimensionData.new company
    elsif company.id == 288
      @single_dimension_service = ::HrisIntegrationsService::Bamboo::Forward::ManageSaplingSingleDimensionData.new company
    elsif company.id == 363
      @single_dimension_service = HrisIntegrationsService::Bamboo::Recursion::ManageSaplingSingleDimensionData.new company
    else
      @single_dimension_service = ::HrisIntegrationsService::Bamboo::ManageSaplingSingleDimensionData.new company
    end

    if company.id == 34
      @tabular_data_service = ::HrisIntegrationsService::Bamboo::Addepar::ManageSaplingTabularData.new company
    elsif company.id == 185
      @tabular_data_service = ::HrisIntegrationsService::Bamboo::Doordash::ManageSaplingTabularData.new company
    elsif company.id == 288
      @tabular_data_service = ::HrisIntegrationsService::Bamboo::Forward::ManageSaplingTabularData.new company
    else
      @tabular_data_service = ::HrisIntegrationsService::Bamboo::ManageSaplingTabularData.new company
    end
  end

  def perform
    bamboo_users = []

    begin
      bamboo_users = is_update_all ? fetch_bamboo_employees : fetch_updated_bamboo_employees
    rescue Exception => e
      puts "--------------------------Bamboo Error(Company: #{company.id})------------------------"
      puts e.inspect

      log("User In Sapling Failure", {}, {response: e.message}, 500)
      puts "--------------------------------------------------------------------------------------"
    end

    bamboo_users.try(:each) do |bamboo_user|
      begin
        data = is_update_all ? bamboo_user : find_bamboo_employee(bamboo_user.first)
        manage_sapling_user(data)
      rescue Exception => e
        puts "--------------------------Bamboo Error(Company: #{company.id})------------------------"
        puts bamboo_user.inspect
        puts e.inspect

        log("User In Sapling Failure", {}, {response: e.message, received_data: bamboo_user}, 500)
        puts "--------------------------------------------------------------------------------------"
      end
    end
  end

  private

  def employee
    ::HrisIntegrationsService::Bamboo::Employee.new company
  end

  def fetch_user(bamboo_id, personal_email, email)
    users = company.users.where('current_stage != ?', User.current_stages[:incomplete])

    user = fetch_user_by_bamboo_id(users, bamboo_id)
    if user.blank?
      user = fetch_user_by_email(users, email, personal_email)
    end

    user
  end

  def fetch_user_by_bamboo_id(users, bamboo_id)
    if bamboo_id.present?
      return users.where('bamboo_id = ?', bamboo_id).take
    end
  end

  def fetch_user_by_email(users, email, personal_email)
    user = nil

    if email.present?
      user = users.where('personal_email ILIKE ? OR email ILIKE ?', email, email).take
    end

    if user.blank? && personal_email.present?
      user = users.where('personal_email ILIKE ? OR email ILIKE ?', personal_email, personal_email).take
    end

    user
  end

  def can_user_be_created?(data)
    !fetch_user(data['id'], data['homeEmail'], data['workEmail']).present? && (data['employmentHistoryStatus'].try(:downcase) != 'terminated' || data['status'].try(:downcase) != 'inactive')
  end

  def can_user_be_updated?(data)
    fetch_user(data['id'], data['homeEmail'], data['workEmail']).present? && (!company.users.exists?(bamboo_id: data['id'], last_changed: data['lastChanged']) || is_update_all.present?)
  end

  def can_user_be_terminated?(data)
    fetch_user(data['id'], data['homeEmail'], data['workEmail']).present? && (data['employmentHistoryStatus'].try(:downcase) == 'terminated' || data['status'].try(:downcase) == 'inactive')
  end

  def apply_action_on_user user, data, action
    if user.present?
      log("#{user.id}: #{action} User In Sapling (#{data['id']}) - Success", {request: "GET USERS/#{data['id']}"}, {response: user.inspect, received_data: data}, 200)

      @single_dimension_service.manage_custom_fields(user)
      @single_dimension_service.manage_custom_groups(user)
      @single_dimension_service.manage_profile_photo(user)
      @single_dimension_service.manage_profile_data(user) if @company.id == 288

      @tabular_data_service.manage_custom_fields(user)
      bamboo_integration = @company.integration_instances.find_by(api_identifier: 'bamboo_hr', state: :active)
      bamboo_integration.update_column(:synced_at, DateTime.now) if bamboo_integration
    end
  end

  def manage_sapling_user(data)
    return if !data.present?
    @single_dimension_service.initialize_bamboo_data(data)
    user = nil
    action = nil
    company.reload
    begin
      if can_user_be_created?(data)
        action = 'Create'
        user = create_sapling_user
        apply_action_on_user(user, data, action)
      elsif can_user_be_terminated?(data)
        action = 'Terminate'
        user = terminate_sapling_user
        apply_action_on_user(user, data, action) if user.present?
      elsif can_user_be_updated?(data)
        action = 'Update'
        user = fetch_user(data['id'], data['homeEmail'], data['workEmail'])
        original_user = user.dup
        user = update_sapling_user user
        apply_action_on_user(user, data, action)
        ::Inbox::UpdateScheduledEmail.new.update_scheduled_user_emails(user.reload, original_user)
      end

      log("#{action} User In Sapling (#{data['id']}) - Success", {request: "GET USERS/#{data['id']}"}, {received_data: data}, 200)
    rescue Exception => exception
      log("#{action} User In Sapling (#{data['id']}) - Failure", {request: "GET USERS/#{data['id']}"}, {response: exception.message, received_data: data}, 500)
    end
  end

  def create_sapling_user
    data = @single_dimension_service.prepare_user_data(true)
    company.reload

    if !company.users.find_by_bamboo_id(data[:bamboo_id]).present?
      user = company.users.create!(data)
    end
  end

  def update_sapling_user user
    data = @single_dimension_service.prepare_user_data
    user.update!(data)
    return user
  end

  def terminate_sapling_user
    data = @single_dimension_service.prepare_user_data(false, true)
    user = company.users.find_by_bamboo_id(data[:bamboo_id]) || fetch_user(data[:bamboo_id], data[:personal_email], data[:email])

    return if user.is_rehired

    user.offboarded!
    user.calendar_feeds.destroy_all
    user.tasks.update_all(owner_id: nil)
    original_user = user.dup
    user.update!(data)
    ::Inbox::UpdateScheduledEmail.new.update_scheduled_user_emails(user, original_user)
    return user
  end

  def log(action, request, response, status)
    LoggingService::IntegrationLogging.new.create(@company, 'BambooHR', action, request, response, status)
  end
end
