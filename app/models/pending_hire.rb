class PendingHire < ApplicationRecord
  has_paper_trail
  acts_as_paranoid
  belongs_to :company
  belongs_to :user
  belongs_to :location
  belongs_to :team
  belongs_to :manager, class_name: 'User'
  validates :company_id, presence: true
  validates :user_id, uniqueness: { scope: :company_id }, if: -> {user_id.present? && company_id.present?}
  # before_save :set_start_date, if: Proc.new { |pending_hire| pending_hire.start_date.present? }

  before_validation :date_converter, if: Proc.new { |pending_hire| pending_hire.start_date.present? }, on: :create
  before_save { set_start_date_to_nil if !self.start_date.nil? && self.start_date.blank? }

  after_create :set_guid
  after_commit Proc.new{ create_webhook_events('created') }, on: :create
  after_create :send_pending_hire_notification
  
  after_update { create_webhook_events('updated') if send_update_to_webhooks? }
  before_destroy { create_webhook_events('deleted') }
  
  validate :user_exists, on: :create,  if: Proc.new { |pending_hire| pending_hire.skipping_duplication == nil  || pending_hire.skipping_duplication == false}

  enum send_credentials_type: {
    immediately: 0,
    before: 1,
    on: 2,
    dont_send: 3
  }
  attr_accessor :skipping_duplication

  enum duplication_type: {inactive: 0, info_change: 1, active: 2, rehire: 3}

  scope :with_workday, -> { where.not(workday_id: nil) }

  def set_guid
    update_column(:guid, generate_unique_guid)
  end

  def generate_unique_guid
    loop do
      temp_guid = "#{Time.now.to_i}#{SecureRandom.uuid}"
      break temp_guid unless self.company.pending_hires.with_deleted.where(guid: temp_guid).exists?
    end
  end

  def user_exists
    if self.personal_email && self.company
      user = self.company.users.where('email = ? OR personal_email = ? ', self.personal_email, self.personal_email).take
      pending_hire = self.company.pending_hires.find_by(personal_email: self.personal_email)
      if pending_hire.present?
        errors.add(:Email, I18n.t('admin.people.create_profile.pending_hire_exists'))
      elsif user.present?
        self.user_id = user.id
        if user.current_stage == 'departed'
          PendingHire.create_general_logging(self.company, 'PendingHire', {result: "Created new Pending Hire against inactive user #{self.user_id}"})
          self.duplication_type = PendingHire.duplication_types[:inactive]
        else
          if self.changed_info.empty?
            self.duplication_type = PendingHire.duplication_types[:active]
          elsif self.changed_info.present?
            PendingHire.create_general_logging(self.company, 'PendingHire', {result: "Created new Pending Hire against active user #{self.user_id}"})
            self.duplication_type = PendingHire.duplication_types[:info_change]
          end
        end
      end
    elsif self.user_id && self.user.pending_hire.try(:id).present?
      errors.add(:Email, I18n.t('admin.people.create_profile.pending_hire_exists'))
    end
  end

  def send_pending_hire_notification
    begin
      Interactions::Users::PendingHireNotificationEmail.new(self).perform unless self.user_id && self.user.incomplete?
    rescue
    end
  end

  def self.create_by_lever_mapping(params, company)
    params[:location_id] = get_location(params[:location_id], company)&.id if params[:location_id].present?
    params[:team_id] = get_team(params[:team_id], company)&.id if params[:team_id].present?
    PendingHire.create!(params)
  end

  def self.create_by_lever(candidate_data, candidate_posting_data, candidate_hiring_manager, hired_candidate_profile_form_fields, company, offer_data = nil, referral_data = nil, hired_candidate_requisition = nil)
    lever_custom_fields = []

    first_name, last_name = get_name(candidate_data['name'])
    email = candidate_data['emails'][0] rescue nil
    phone_number = candidate_data['phones'][0]['value'] rescue nil

    if candidate_data['sources'].present? && candidate_data['sources'].length > 0
      source_field = { "text" => "Source", "identifier" => "sources", "value" => candidate_data['sources'][0] }
      lever_custom_fields.push(source_field)
    end
    if referral_data.present?
      referral_field = { "text" => "Referrer", "identifier" => "referrals", "value" => referral_data['value'] }
      lever_custom_fields.push(referral_field)
    end

    #TO DO - CHANGE ARCHITECTURE FOR HANDLING MORE COMPANIES

    start_date_field = hired_candidate_profile_form_fields.try(:select) { |form_field| form_field['text'].try(:downcase) == 'start date' }
    if start_date_field.present?
      start_date = DateTime.strptime(((start_date_field.first['value']).to_f / 1000).to_s, '%s').to_date rescue nil
    else
      start_date = DateTime.strptime(((candidate_data['archived']['archivedAt'] + ActiveSupport::TimeZone[company.time_zone].utc_offset).to_f / 1000).to_s, '%s').in_time_zone(company.time_zone).to_date rescue nil
    end

    manager_id = nil
    if candidate_hiring_manager.present?
      manager = company.users.find_by(email: candidate_hiring_manager) || company.users.find_by(personal_email: candidate_hiring_manager)
      manager_id = manager.try(:id)
    end

    base_salary = nil
    location = nil
    preferred_name = nil

    if offer_data.present?
      for field in offer_data['fields']
        case field['identifier']
        when "anticipated_start_date"
          start_date = DateTime.strptime((field['value'] / 1000).to_s, '%s').to_date rescue nil
        when "team", "custom_team"
          if company.subdomain == 'toptal' && field['identifier'] == 'custom_team'
            lever_custom_fields.push(field)
          else
            team = get_team(field['value'], company) rescue nil
          end
        when "salary_amount"
          lever_custom_fields.push(field)
          base_salary = field['value'].round rescue 0
        when "location", "custom_location"
          location = get_location(field['value'], company) rescue nil
        when "custom_employment_status"
          employee_type = field['value'] rescue nil
        when "custom_preferred_name"
          if company.subdomain == 'toptal'
            preferred_name = field['value'] rescue nil
          end
          lever_custom_fields.push(field)
        else
          if ['toptal', 'clari'].include?(company.subdomain)
            if field['text'].present?
               coworker_field = company.custom_fields.where('name ILIKE ? AND field_type = ?', field['text'], CustomField.field_types[:coworker]).take
              if coworker_field.present? && coworker_field.coworker?
                if field['value'].present?
                  lever_user = fetch_user_from_lever(field['value'], company)

                  if lever_user.present?
                    employee = company.users.where("email ILIKE ? OR personal_email ILIKE ?", lever_user, lever_user).take
                    if employee.blank?
                      employee = company.users.where("CONCAT_WS(' ', first_name, last_name) ILIKE ?", lever_user).take
                      if employee.blank?
                        employee = company.users.where("CONCAT_WS(' ', preferred_name, last_name) ILIKE ?", lever_user).take
                      end
                    end

                    if employee.present?
                      field['employee_id'] = employee.id
                      field['first_name'] = employee.first_name
                      field['last_name'] = employee.last_name
                      field['preferred_name'] = employee.preferred_name
                    end
                  end
                end
              end
            end
          end

          lever_custom_fields.push(field)
        end
      end
    end

    if !location.present?
      location_field = hired_candidate_profile_form_fields.try(:select) { |form_field| form_field['text'].try(:downcase) == 'location' }
      if location_field.present?
        location = get_location(location_field.first['value'], company) rescue nil
      end
    end

    if candidate_posting_data.present?
      title = candidate_posting_data['text'] rescue nil

      if company.subdomain == 'toptal'
        team ||= get_team(candidate_posting_data['categories']['department'], company) rescue nil
      else
        team ||= get_team(candidate_posting_data['categories']['team'], company) rescue nil
      end
      location ||= get_location(candidate_posting_data['categories']['location'], company) rescue nil
      if ['mryum', 'vennbio', 'camelotillinois'].include?(company.subdomain)
        employee_type = candidate_posting_data['categories']['commitment'] rescue nil
      else
        employee_type ||= get_employee_type(candidate_posting_data['categories']['commitment']) rescue nil
      end
    end

    if hired_candidate_requisition.present?
      company.custom_fields.where.not(lever_requisition_field_id: nil).each do |custom_field|
          if ["name", "requisitionCode", "internalNotes", "employmentStatus", "location", "team", "department"].include?(custom_field.lever_requisition_field_id)
            value = hired_candidate_requisition[custom_field.lever_requisition_field_id] rescue nil
          else
            value = hired_candidate_requisition["customFields"][custom_field.lever_requisition_field_id] rescue nil
          end
          if value.present?
            requisition_field = { "text" => custom_field.name, "identifier" => "requisitions", "value" => value }
            lever_custom_fields.push(requisition_field)
            if custom_field.lever_requisition_field_id == "employmentStatus"
              employee_type = value
            end
          end
      end if hired_candidate_requisition["customFields"].present?
      # default fields
      company.prefrences["default_fields"].each do |default_field|
        if default_field["lever_requisition_field_id"].present?
          if ["name", "requisitionCode", "internalNotes", "employmentStatus", "location", "team", "department"].include?(default_field["lever_requisition_field_id"])
            value = hired_candidate_requisition[default_field["lever_requisition_field_id"]] rescue nil
          else
            value = hired_candidate_requisition["customFields"][default_field["lever_requisition_field_id"]] rescue nil
          end
          if value.present?
            case default_field["name"]
            when "Job Title"
              title = value
            when "Location"
              location = get_location(value, company)
            when "Department"
              team = get_team(value, company)
            end
          end
        end
      end
    end

    PendingHire.create!(first_name: first_name, last_name: last_name, personal_email: email,
      title: title, location_id: location.try(:id), phone_number: phone_number, company_id: company.id,
      team_id: team.try(:id), start_date: start_date, employee_type: employee_type, manager_id: manager_id,
      base_salary: base_salary, preferred_name: preferred_name, lever_custom_fields: lever_custom_fields)
  end

  def changed_info
    exlude_keys = ["title", "location_id", "phone_number", "team_id", "manager_id" ,"start_date", "employee_type", "first_name", "last_name", "address_line_1", "address_line_2", "city", "address_state", "zip_code"]
    user = self.user
    pending_hire_attributes = self.attributes
    changes = []
    user_home_address = self.user.get_custom_field_value_text('Home Address', true) if self.address_line_1.present?
    pending_hire_attributes.each do |attri|
      if exlude_keys.include?(attri[0]) && attri[1].present?
        data = {}
        case attri[0]
        when "title"
          data = {heading: "Job Title", old: user.title, new: attri[1], attribute: 'jt'} if attri[1] != user.title
        when "location_id"
          data = {heading: "Location", old: user.location.try(:name), new: self.location.try(:name), attribute: 'loc'} if attri[1] != user.location_id
        when "phone_number"
          data = {heading: "Phone number", old: user.get_custom_field_value_text('Mobile Phone Number'), new: attri[1], attribute: 'phone_number'} if attri[1] != user.get_custom_field_value_text('Mobile Phone Number')
        when "team_id"
          data = {heading: "Team", old: user.team.try(:name), new: self.team.try(:name), attribute: 'dpt'} if attri[1] != user.team_id
        when "manager_id"
          data = {heading: "Manager", old: user.manager.try(:full_name), new: self.manager.try(:full_name) , attribute: 'man'} if attri[1] != user.manager_id
        when "start_date"
          data = {heading: "Start Date", old: user.start_date, new: attri[1], attribute: 'start_date'} if user.start_date != attri[1].to_date
        when "employee_type"
          data = {heading: "Employment Status", old: user.employee_type, new: attri[1], attribute: 'Employment Status'} if attri[1] != user.employee_type
        when "first_name"
          data = {heading: "First Name", old: user.first_name, new: attri[1], attribute: 'first_name'} if attri[1] != user.first_name
        when "last_name"
          data = {heading: "Last Name", old: user.last_name, new: attri[1], attribute: 'last_name'} if attri[1] != user.last_name
        when "address_line_1"
          data  = {heading: "Line 1", old: user_home_address[:line1], new: attri[1], attribute: 'line1'} if self.address_line_1.present?  && self.address_line_1 != user_home_address[:line1]
        when "address_line_2"
          data  = { heading: "Line 2", old: user_home_address[:line2], new: attri[1], attribute: 'line2'} if self.address_line_1.present? && self.address_line_2.present? && self.address_line_2 != user_home_address[:line2]
        when "city"
          data  = {heading: "City", old: user_home_address[:city], new: attri[1], attribute: 'city'} if self.address_line_1.present? && self.city.present? && self.city != user_home_address[:city]
        when "address_state"
          data  = {heading: "State", old: user_home_address[:state], new: attri[1], attribute: 'address_state'} if self.address_line_1.present? && self.address_state.present? && self.address_state != user_home_address[:state]
        when "zip_code"
          data  = {heading: "Zip", old: user_home_address[:zip], new: attri[1], attribute: 'zip'} if self.address_line_1.present? && self.zip_code.present? && self.zip_code != user_home_address[:zip]
        end
        changes.push(data) if data.present?
      end
    end
    changes
  end

  def self.create_by_greenhouse(data, company)
    preferences = company.prefrences['default_fields']

    candidate_data = data['candidate']
    job_data = data['job']
    jobs_data = data['jobs']
    offer_date = data['offer']
    params = {}
    email = ''

    preferences.each do |preference|
      if preference['ats_mapping_section'].blank?
        if preference['name'] == 'First Name'
          params[:first_name] = candidate_data['first_name'] rescue nil
        elsif preference['name'] == 'Last Name'
          params[:last_name] = candidate_data['last_name'] rescue nil
        elsif preference['name'] == 'Personal Email'
          params[:personal_email] = candidate_data['email_addresses'][0]['value'] rescue nil
        elsif preference['name'] == 'Job Title'
          params[:title] = jobs_data.first['name'] rescue nil
        elsif preference['name'] == 'Location'
          params[:location_id] = get_location(jobs_data.first['offices'][0]['name'], company).try(:id) rescue nil
        elsif preference['name'] == 'Department'
          department = jobs_data.first['departments'][0]['name'] rescue nil
          if department.blank?
            department = job_data['departments'][0]['name'] rescue nil
          end
          params[:team_id] = get_team(department, company).try(:id) rescue nil
        elsif preference['name'] == 'Manager'
          hiring_manager = jobs_data.first['hiring_team']['hiring_managers'][0] rescue nil
          manager = nil
          if hiring_manager.present?
            manager = company.users.find_by(id: hiring_manager['employee_id'].to_i) rescue nil
            if manager.blank?
              manager = get_employee_from_company(company, {email: hiring_manager['email'], name: hiring_manager['name']}) rescue nil
            end
          end
          params[:manager_id] = manager.try(:id)
        elsif preference['name'] == 'Start Date'
          params[:start_date] = data['offer']['starts_at'] rescue nil
        end
      elsif preference['ats_integration_group'] == 'greenhouse'

        sub_data = data[preference['ats_mapping_section']]
        if sub_data.is_a? Array
          value = data[preference['ats_mapping_section']].first['custom_fields'][preference['ats_mapping_key']]['value'] rescue nil
        else
          value = data[preference['ats_mapping_section']]['custom_fields'][preference['ats_mapping_key']]['value'] rescue nil
        end

        if value.is_a? Hash
          value = value['name'] rescue nil
          email = value['email'] rescue nil
        elsif value.is_a? Array
          value = value[0]
        end

        if preference['name'] == 'First Name'
          params[:first_name] = value
        elsif preference['name'] == 'Last Name'
          params[:last_name] = value
        elsif preference['name'] == 'Personal Email'
          params[:personal_email] = value
        elsif preference['name'] == 'Job Title'
          params[:title] = value
        elsif preference['name'] == 'Location'
          params[:location_id] = get_location(value, company).try(:id) rescue nil
        elsif preference['name'] == 'Department'
          params[:team_id] = get_team(value, company).try(:id) rescue nil
        elsif preference['name'] == 'Manager'
          #for tracing error
          create_general_logging(company, "GreenHouse Manager Log - #{company.id}- Manager Change", [{object_class: value.class.to_s, value: value}, {object_class: email.class.to_s, email: email}])
          manager = get_employee_from_company(company, {email: email, name: value}) rescue nil
          params[:manager_id] = manager.try(:id)
        elsif preference['name'] == 'Preferred Name'
          params[:preferred_name] = value
        elsif preference['name'] == 'Start Date'
          params[:start_date] = value
        end
      end
    end
    
    params[:phone_number] = candidate_data['phone_numbers'][0]['value'] rescue nil
    employee_type = offer_date['custom_fields']['employment_type']['value'] rescue nil
    custom_field = company.custom_fields.find_by_field_type(13)
    params[:employee_type] = custom_field.get_mapping_field_option(employee_type) if employee_type && !custom_field.try(:ats_mapping_key).present?

    if candidate_data['recruiter'] && candidate_data['recruiter']['email'] && company.custom_fields.where(ats_mapping_key: "recruiter", ats_mapping_section: "candidate").present?
      email = candidate_data['recruiter']['email'] rescue nil
      recruiter = company.users.where('email ILIKE ? OR personal_email ILIKE ?', email, email).take if email.present?
      candidate_data['recruiter']['employee_id'] = recruiter.try(:id)
      candidate_data['recruiter']['preferred_name'] = recruiter.try(:preferred_name)
      candidate_data['recruiter']['first_name'] = recruiter.try(:first_name)
      candidate_data['recruiter']['last_name'] = recruiter.try(:last_name)
    end

    company.custom_fields.where.not(ats_mapping_section: nil, ats_mapping_key: [nil, "recruiter"]).where(field_type: 11).each do |custom_field|
      if data[custom_field.ats_mapping_section] && data[custom_field.ats_mapping_section]["custom_fields"] && data[custom_field.ats_mapping_section]["custom_fields"][custom_field.ats_mapping_key]
        email = data[custom_field.ats_mapping_section]["custom_fields"][custom_field.ats_mapping_key]["value"]["email"] rescue nil
        coworker = company.users.where('email ILIKE ? OR personal_email ILIKE ?', email, email).take if email.present?
        data[custom_field.ats_mapping_section]["custom_fields"][custom_field.ats_mapping_key]['employee_id'] = coworker.try(:id)
        data[custom_field.ats_mapping_section]["custom_fields"][custom_field.ats_mapping_key]['preferred_name'] = coworker.try(:preferred_name)
        data[custom_field.ats_mapping_section]["custom_fields"][custom_field.ats_mapping_key]['first_name'] = coworker.try(:first_name)
        data[custom_field.ats_mapping_section]["custom_fields"][custom_field.ats_mapping_key]['last_name'] = coworker.try(:last_name)
      end
    end

    pending_hire = company.pending_hires.find_by(personal_email: params[:personal_email])
    pending_hire.delete_hire if pending_hire.present?
    PendingHire.create(params.merge!({custom_fields: data, is_basic_format_custom_data: false, company_id: company.id, source: 'green_house'}))
  end

  def self.create_by_greenhouse_mail_parser(data, company)
    first_name = data['first_name'] rescue nil
    last_name = data['last_name'] rescue nil
    personal_email = data['personal_email'] rescue nil
    phone_number = data['phone_numbers'] rescue nil
    start_date = data['start_date'] rescue nil
    title = data['job_title'] rescue nil
    employee_type = data['employment_type'].parameterize.underscore rescue nil
    location_id = nil
    if data['location']
      location = get_location(data['location'], company)
      location_id = location ? location.id : nil
    end
    team_id = nil
    if data['department']
      team = get_team(data['department'], company)
      team_id = team ? team.id : nil
    end

    manager_id = nil
    if data['manager']
      manager = get_employee_from_company(company, {email: data['manager'], name: data['manager']}) rescue nil
      manager_id = manager.try(:id)
    end

    if data['referred_by']
      data['referred_by'] = co_worker_ats_fields(company, {email: data['referred_by'], name: data['referred_by']})
    end

    if data['recruiter']
      data['recruiter'] = co_worker_ats_fields(company, {email: data['recruiter'], name: data['recruiter']})
    end

    if data['mobile_phone_number']
      data['mobile_phone_number'] = CustomField.parse_phone_string_to_hash(data['mobile_phone_number'])
    end

    base_salary = data['base_salary'] rescue nil
    hourly_rate = data['hourly_rate'] rescue nil
    bonus = data['bonus'] rescue nil
    address_line_1 = data['address_line_1'] rescue nil
    address_line_2 = data['address_line_2'] rescue nil
    city = data['city'] rescue nil
    address_state = data['state'] rescue nil
    zip_code = data['zip_code'] rescue nil
    level = data['level'] rescue nil
    custom_role = data['role'] rescue nil
    flsa_code = data['flsa_code'] rescue nil

    unless personal_email.nil?
      pending_hire = company.pending_hires.find_by(personal_email: personal_email)
      pending_hire.delete_hire if pending_hire.present?
    end
    PendingHire.create(first_name: first_name,
                       last_name: last_name,
                       personal_email: personal_email,
                       phone_number: phone_number,
                       start_date: start_date,
                       title: title,
                       employee_type: employee_type,
                       location_id: location_id,
                       team_id: team_id,
                       manager_id: manager_id,
                       base_salary: base_salary,
                       hourly_rate: hourly_rate,
                       bonus: bonus,
                       address_line_1: address_line_1,
                       address_line_2: address_line_2,
                       city: city,
                       address_state: address_state,
                       zip_code: zip_code,
                       level: level,
                       custom_role: custom_role,
                       flsa_code: flsa_code,
                       company_id: company.id,
                       custom_fields: data
    )
  end

  def self.create_by_workable(data, company)
    team_id = nil
    location_id = nil

    if data[:department]
      team = company.teams.find_by("name ILIKE ?", data[:department])
      team_id = team.id if team
    end

    if data[:location]
      location = company.locations.where("name ILIKE ?", data[:location]).first_or_create do |location|
        location.name = data[:location]
      end
      location_id = location.try(:id)
    end
    PendingHire.create(first_name: data[:first_name],
                       last_name: data[:last_name],
                       personal_email: data[:personal_email],
                       phone_number: data[:phone_number],
                       start_date: data[:start_date],
                       title: data[:title],
                       employee_type: data[:employee_type],
                       team_id: team_id,
                       location_id: location_id,
                       company_id: company.id
    )
  end

  def self.create_by_smart_recruiters(data, company)
    team_id = nil
    location_id = nil

    if data[:department]
      team = get_team(data[:department], company)
      team_id = team ? team.id : nil
    end

    if data[:location]
      location = get_location(data[:location], company)
      location_id = location ? location.id : nil
    end

    data[:location_id] = location_id
    data[:team_id] = team_id
    data.delete(:department)
    data.delete(:location)
    PendingHire.create!(data)
  end

  def self.create_by_fountain(data, company)
    data[:location_id] = get_location(data[:location_id], company)&.id if data[:location_id].present?
    data[:team_id] = get_team(data[:team_id], company)&.id if data[:team_id].present?
    data[:manager_id] = get_employee_from_company(company, {email: data[:manager_id], name: data[:manager_id]})&.id
    data[:company_id] = company.id
    PendingHire.create!(data)
  end

  def delete_hire
    user = self.user
    if user.present? && user.incomplete?
      user.destroy!
    else
      self.update_column(:user_id, nil)
      self.destroy!
    end
  end

  def display_name
    if self.user
      self.user.display_name
    else
      self.company.global_display_name(self, self.company.display_name_format)
    end
  end

  def preferred_full_name
    "#{self.first_name} #{self.last_name}"
  end

  def hashed_phone_number
    return {} unless self.phone_number.present?
    phone_number = self.phone_number.gsub('-', '')
    ret_val = {}

    begin
      phone = Phonelib.parse(phone_number)
      if phone.present? && phone.valid?
        ret_val[:country_alpha3] = ISO3166::Country.find_country_by_alpha2(phone.country).alpha3
        ret_val[:area_code] = phone.area_code
        ret_val[:phone] = phone.national(false)
        ret_val[:phone] = ret_val[:phone].sub(ret_val[:area_code],'') if ret_val[:phone].present? && ret_val[:area_code].present?
        
        if ['PK', 'IN'].include?(phone.country)
          ret_val[:phone][0] = '' if ret_val[:phone] && ret_val[:phone][0] == '0'
        end
      end
    rescue Exception => e
    end
    ret_val
  end

  def full_name
    return self.first_name + ' ' + self.last_name if self.first_name && self.last_name
    return self.first_name if self.first_name
    return self.last_name if self.last_name
  end

  def team_name
    self.team&.name
  end

  def location_name
    self.location&.name
  end

  def manager_name
    self.manager&.full_name
  end

  def create_user
    PendingHireServices::UserManagement.new(self, 'create').call
  end

  def update_user
    PendingHireServices::UserManagement.new(self, 'update').call
  end

  def self.get_employee_from_company(company, user)
    employee = company.active_users.where("email ILIKE ? OR personal_email ILIKE ?", user[:email], user[:email]).take
    if employee.blank?
      employee = company.active_users.where("CONCAT_WS(' ', first_name, last_name) ILIKE ?", user[:name]).take
      if employee.blank?
        employee = company.active_users.where("CONCAT_WS(' ', preferred_name, last_name) ILIKE ?", user[:name]).take
      end
    end
    employee
  end

  def self.co_worker_ats_fields(company, user)
    co_worker_id = nil
    data = nil
    co_worker = get_employee_from_company(company, user)
    if co_worker
      data = { employee_id: co_worker.id, first_name: co_worker.first_name, last_name: co_worker.last_name, preferred_name: co_worker.preferred_name }
    end
    data
  end

  def set_custom_group_field_option(field_id, option_id)
    self.user.custom_field_values.find_or_create_by(custom_field_id: field_id)&.update(custom_field_option_id: option_id)
  end

  private

  # def set_start_date
  #   begin
  #     self.start_date = self.start_date.to_date.to_s
  #   rescue Exception => e
  #     self.start_date = nil
  #     create_general_logging(self.company, 'PendingHire', {result: "Pending Hire Creation Failure", message: e.inspect, pending_hire: self.inspect})
  #   end
  # end

  def self.get_name(name)
    if name.present?
      name.split(' ', 2)
    end
  end

  def self.get_location(location, company)
    if company
      company.locations.find_by('name ILIKE ?', location.strip)
    end
  end

  def self.get_team(team, company)
    if company
      company.teams.find_by('name ILIKE ?', team.strip)
    end
  end

  def self.get_employee_type(type)
    if type.present?
      type.parameterize.underscore
    end
  end

  def date_converter
    date = self.start_date
    self.start_date = Date.strptime(date, self.company.get_date_format) rescue nil
    self.start_date = date.to_datetime rescue nil if self.start_date.blank?
    self.start_date = Date.strptime(date, '%m-%d-%Y') rescue nil if self.start_date.blank?
    self.start_date = Date.strptime(date, '%m/%d/%Y') rescue nil if self.start_date.blank?
    self.start_date = Date.strptime(date, '%Y/%d/%m') rescue nil if self.start_date.blank?
    self.start_date = Date.strptime(date, '%Y-%d-%m') rescue nil if self.start_date.blank?
  end

  def self.create_general_logging(company, action, result, type='Overall')
    LoggingService::GeneralLogging.new.create(company, action, result, type)
  end

  def self.fetch_user_from_lever(user_id, company)
    begin
      api_key = company.integrations.where(api_name: 'lever').take&.api_key
      if api_key.present?
        lever_user_resource = RestClient::Resource.new "https://api.lever.co/v1/users/#{user_id}", "#{api_key}", ''
        lever_user = JSON.parse(lever_user_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))

        lever_user_data = lever_user["data"]
        if lever_user_data.present?
          return (lever_user_data["email"] || lever_user_data['name']).strip
        end
      end
    rescue Exception => e
      LoggingService::WebhookLogging.new.create(company, 'Lever', 'Lever User', {user_id: user_id}, 500, 'PendingHire/fetch_user_from_lever', e.message)
    end
  end

  def set_start_date_to_nil
    self.start_date = nil
  end

  def create_webhook_events(action)
    WebhookEventServices::ManageWebhookEventService.new.initialize_event(company, {event_type: 'new_pending_hire',type: 'new_pending_hire', action: action, pending_hire_id: id, triggered_for: self.user_id, triggered_by: User.current.try(:id)})
  end

  def send_update_to_webhooks?
    changed_attributes = self.saved_changes.keys
    (changed_attributes & ['first_name', 'personal_email', 'last_name', 'preferred_name', 'state', 'employee_type', 'start_date', 'title', 'team_id', 'location_id']).count > 0
  end
end