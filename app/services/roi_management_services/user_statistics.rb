class RoiManagementServices::UserStatistics
  attr_reader :attributes, :method_name, :method_action

  def initialize(attributes, method_name, method_action)
    @attributes = attributes
    @method_name = method_name
    @method_action = method_action
  end

  def perform
    return unless @method_name.present? && @method_action.present? && Rails.env.development?.blank? && Rails.env.staging?.blank?
    begin
      case @method_name
      when 'manage_loggedin_user'
        manage_loggedin_user
      when 'manage_onboarded_user'
        manage_onboarded_user
      when 'manage_updated_user'
        manage_updated_user
      end
    rescue Exception => e
      puts '==================='
      puts e.inspect
      puts '==================='
    end
  end

  private

  def fetch_company(company_id)
    Company.find_by_id(company_id)
  end

  def fetch_object(object_class, object_id)
    object_class.constantize.find_by_id(object_id)
  end

  def fetch_company_and_user_id
    return unless @attributes[:object_class].present? && @attributes[:object_id].present?

    object = fetch_object(@attributes[:object_class], @attributes[:object_id])
    return unless object.present?

    if @attributes[:object_class] == 'User'
      return [ object.company_id, object.id ]
    else
      return [ object.user&.company_id, object.user_id ]
    end
  end

  def date_in_company_timezone(company)
    Date.today.in_time_zone(company.time_zone)
  end

  def create(company_id, company_domain, user_id, date, column_name)
    UserStatistic.create!(company_id: company_id, company_domain: company_domain, record_collected_at: date).add_to_set("#{column_name}": user_id)
  end

   def update(user_statistic, user_id, column_name)
    return unless user_statistic.present?

    user_statistic.add_to_set("#{column_name}": user_id)
  end

  def create_or_update(company_id, user_id, column_name)
    company = fetch_company(company_id)
    return unless company.present? && user_id.present? && column_name.present?

    date = date_in_company_timezone(company)

    user_statistic = UserStatistic.of_specific_day(company_id, company.domain, date)
    user_statistic.blank? ? create(company_id, company.domain, user_id, date, column_name) : update(user_statistic, user_id, column_name)
  end

  def manage_loggedin_user
    create_or_update(@attributes[:company_id], @attributes[:user_id], 'loggedin_user_ids')
  end

  def manage_onboarded_user
    create_or_update(@attributes[:company_id], @attributes[:user_id], 'onboarded_user_ids')
  end

  def manage_updated_user
    company_id, user_id = fetch_company_and_user_id
    create_or_update(company_id, user_id, 'updated_user_ids')
  end
end
