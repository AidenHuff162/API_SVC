class Webhook < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: 'User'
  belongs_to :updated_by, class_name: 'User'
  has_many :webhook_events, dependent: :destroy

  enum state: { active: 0, inactive: 1 }
  enum event: { stage_completed: 0, new_pending_hire: 1, stage_started: 2, key_date_reached: 3, profile_changed: 4, job_details_changed: 5, onboarding: 6, offboarding: 7}
  enum created_from: { app: 0, api_call: 1 }
  scope :existing_webhooks, -> (event) { where(event: event).where(state: Webhook.states[:active]).count }

  validates_format_of :target_url, with: Regexp.new(URI::regexp), allow_nil: false, message: I18n.t('api_notification.invalid_attribute_value', attribute: 'url'), unless: -> {self.zapier?}

  after_create :set_guid
  after_create :set_references
  after_update :update_references

  DATE_TYPES = ['start date', 'birthday', 'anniversary date', 'last day worked', 'termination date']

  PROFILE_SECTIONS = ['profile', 'private_info', 'additional_fields', 'personal_info']
  EXCLUDED_FIELDS = ['user_id', 'profile photo', 'access permission', 'effective date']

  def extract_configurable
    self.configurable['stages'] || self.configurable['date_types'] || self.configurable['fields'] rescue nil
  end

  def self.webhooks_by_filters(company, user_id)
    user = company.users.unscoped.find_by(id: user_id)
    return Webhook.none if user.blank?

    employment_status = user.get_employment_status_option
    employee_status = employment_status.present? ? [employment_status] : ['all']
    team = user.team_id.present? ? [user.team_id] : ['all']
    location = user.location_id.present? ? [user.location_id] : ['all']
    where("(filters -> 'location_id' @> ? AND filters -> 'employee_type' @> ? AND filters -> 'team_id' @> ?) OR
      (filters -> 'location_id' @> ? AND filters -> 'employee_type' @> ? AND filters -> 'team_id' @> ?) OR
      (filters -> 'location_id' @> ? AND filters -> 'employee_type' @> ? AND filters -> 'team_id' @> ?) OR
      (filters -> 'location_id' @> ? AND filters -> 'employee_type' @> ? AND filters -> 'team_id' @> ?) OR
      (filters -> 'location_id' @> ? AND filters -> 'employee_type' @> ? AND filters -> 'team_id' @> ?) OR
      (filters -> 'location_id' @> ? AND filters -> 'employee_type' @> ? AND filters -> 'team_id' @> ?) OR
      (filters -> 'location_id' @> ? AND filters -> 'employee_type' @> ? AND filters -> 'team_id' @> ?) OR
      (filters -> 'location_id' @> ? AND filters -> 'employee_type' @> ? AND filters -> 'team_id' @> ?)",
        location.to_s, employee_status.to_s, team.to_s, location.to_s, '["all"]', '["all"]', '["all"]',
        employee_status.to_s, '["all"]', '["all"]', '["all"]', team.to_s, location.to_s, employee_status.to_s, '["all"]', location.to_s, '["all"]',
        team.to_s, '["all"]', employee_status.to_s, team.to_s, '["all"]', '["all"]', '["all"]')
  end
  
  def self.get_formatted_date_time date, current_company, time_format_half_day
    date = DateTime.parse(date).in_time_zone(current_company.time_zone) if current_company.time_zone.present?
    get_date = TimeConversionService.new(current_company).perform(date.to_date) rescue ''
    get_time = time_format_half_day ? (date.to_datetime.strftime("%I:%M %p") rescue '') : (date.to_datetime.strftime("%H:%M") rescue '')
    {date: get_date, time: get_time}
  end

  def self.get_applied_to_teams filters, current_company
    teams = filters['team_id'].reject(&:blank?)
    (teams.include? 'all') ? ['All Departments'] : current_company.teams.where(id: teams).pluck(:name)
  end

  def self.get_applied_to_locations filters, current_company
    locations = filters['location_id'].reject(&:blank?)
    (locations.include? 'all') ? ['All Locations'] : current_company.locations.where(id: locations).pluck(:name)
  end

  def self.get_applied_to_statuses filters, current_company
    statuses = filters['employee_type'].reject(&:blank?)
    (statuses.include? 'all') ? ['All Statuses'] : statuses.reject(&:empty?)
  end

  def self.get_configurables(configurables, current_company)
    if configurables["stages"].present?
      return configurables["stages"].include?("all") ? ["All Stages"] : configurables["stages"].map { |stage| stage.gsub("_", " ").titleize }
    elsif configurables["date_types"].present?
      return configurables["date_types"].include?("all") ? ["All Dates"] : configurables["date_types"].map { |stage| stage.gsub("_", " ").titleize }
    elsif configurables["fields"].present?
      current_company.get_default_prefrences_field_names(configurables["fields"]) + CustomField.get_custom_field_name(configurables["fields"], current_company)
    end
  end

  private

  def set_guid
    update_column(:guid, generate_unique_guid)
  end

  def generate_unique_guid
    "#{SecureRandom.uuid}-#{id}#{Time.now.to_i}"
  end

  def set_references
    created_by_reference = api_call? ? 'Sapling API Endpoint' : (created_by&.email || created_by&.personal_email)
    updated_by_reference = api_call? ? 'Sapling API Endpoint' : (updated_by&.email || updated_by&.personal_email)

    update_columns(created_by_reference: created_by_reference, updated_by_reference: updated_by_reference)
  end

  def update_references
    updated_by_reference = api_call? ? 'Sapling API Endpoint' : (updated_by&.email || updated_by&.personal_email)

    update_columns(updated_by_reference: updated_by_reference)
  end
end
