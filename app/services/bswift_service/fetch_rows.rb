class BswiftService::FetchRows

  TIME_STATUS_MAP = { 'Full Time Salary': '1', 'Part Time Hourly': '2', 'Seasonal Salary': '3',
                      'Contract Hourly': '4', 'Full Time Hourly': '5', 'Part Time Salary': '6',
                      'Seasonal Hourly': '7' }

  BENEFIT_CLASS_CODE_MAP = { 'Benefits Eligible': 'BE', 'Not Benefits Eligible': 'NBE', 'COBRA': 'COBRA' }

  def initialize(user, integration, company)
    @user = user
    @integration = integration
    @company = company
    @values = []
    @errors = []
  end

  def perform
    if @integration.bswift_group_number.present?
      @values.push(@integration.bswift_group_number)  # Group Number
    else
      @errors.push("Group Number missing in integration configuration")
    end

    ssn = get_custom_field_value_text(@user, "Social Security Number")
    if ssn
      @values.push(ssn) # @userID
      @values.push(ssn) # Social Security Number
    else
      @errors.push("Could not find Social Security Number")
    end

    @values.push(get_employee_id_field_value) # EmployeeID
    @values.push(@user.id.to_s) # Payroll ID
    if @integration.bswift_relation.present?
      @values.push(@integration.bswift_relation)  # Relation
    else
      @errors.push("Relation missing in integration configuration")
    end
    @values.push(@user.first_name) # First Name

    middle_initial = get_custom_field_value_text(@user, "Middle Name")[0].capitalize rescue ""
    @values.push(middle_initial) # Middle Initial (OPTIONAL)

    @values.push(@user.last_name) # Last Name
    @values.push(@user.active? ? 'A' : 'T') # Employment Status

    benefit_class_code = get_custom_field_value_text(@user, "Benefit Class Code")
    if benefit_class_code == "Do Not Send"
      @errors.push("Do Not Send benefit class code")
      @user.update!(sent_to_bswift: true)
    end
    benefit_class_code_mapped = BENEFIT_CLASS_CODE_MAP[benefit_class_code.try(:to_sym)]

    if benefit_class_code_mapped.present?
      @values.push(benefit_class_code_mapped)  # Benefit Class Code
    else
      @errors.push("user does not have a Benefit Class Code not present or field is malconfigured")
    end

    @values.push(date_converter("employment_status"))  # Benefit Class Date 

    @values.push(@user.start_date.strftime('%m/%d/%Y')) # Hire date
    @values.push(@user.is_rehired ? @user.start_date.strftime('%m/%d/%Y') : "") # Rehire Date (OPTIONAL)

    if @user.current_stage == "departed" && @user.termination_date.present?
      @values.push(@user.termination_date)
      @values.push("1")
    else
      @values.push("") # Termination Date (not in v0)
      @values.push("") # Termination Reason (not in v0)
    end

    @user.title.present? ? @values.push(@user.title) : @errors << "user does not have job title" # Job Title

    time_status = get_custom_field_value_text(@user, "Time Status")
    time_status_id = TIME_STATUS_MAP[time_status.try(:to_sym)]

    if time_status && time_status_id
      @values.push(time_status_id) # Time Status
    else
      @errors.push("user does not have a Time Status, or Time Status custom field is malfigured")
    end

    # Salary field should only be present for Salaried Employees
    salary = nil
    if ['1', '3', '6'].include?(time_status_id)
      if @company.subdomain == "clearbit"
        salary = get_custom_field_value_text(@user, "pay rate (base)")
      else
        salary = get_custom_field_value_text(@user, "annual salary")
      end
      if salary
        @values.push(salary) # Salary
      else
        @errors.push("user with salary time status did not have Salary, or Salary field is malfigured")
      end
    else
      @values.push("") # Salary
    end

    # Hourly Rate should only be present for hourly employees
    if ['2', '4', '5'].include?(time_status_id)
      if @company.subdomain == "clearbit"
        hourly_rate = get_custom_field_value_text(@user, "pay rate (base)")
      else
        hourly_rate = get_custom_field_value_text(@user, "pay rate")
      end
      if hourly_rate
        @values.push(hourly_rate) # Hourly Rate
      else
        @errors.push("user with hourly time status did not have Pay Rate, or Pay Rate field is malfigured")
      end
    else
      @values.push("") # Hourly Rate
    end

    hours = get_custom_field_value_text(@user, "hours per week")

    if hours
      @values.push(hours) # Hours Per Week
    else
      if ['2', '4', '5'].include?(time_status_id)
        @errors.push("user with hourly time status did not have Hours Per Week, or Hours Per Week field is malfigured")
      else
        @values.push("") # Hours Per Week
      end
    end

    @values.push("") # Bonus (not in v0, OPTIONAL)
    @values.push("") # Bonus Effective Date (not in v0, OPTIONAL)
    @values.push("") # Commission (not in v0, OPTIONAL)
    @values.push("") # Commission Effective Date (not in v0, OPTIONAL)

    # Benefits Base Salary = Salary + Commission (0) + Bonus(0) = Salary
    if ['1', '3', '6'].include?(time_status_id) && salary
      @values.push(salary) # Benefits Base Salary
    else
      @values.push("") # Benefits Base Salary (blank for hourly employees)
    end
    
    @values.push(date_converter("compensation"))  # Compensation Date

    pay_freq = get_custom_field_value_text(@user, "pay schedule") || get_custom_field_value_text(@user, "pay frequency")
    if pay_freq
      @values.push(pay_freq.try(:downcase))
    else
      @errors.push("user does not have a Pay Frequency, or Pay Frequency / Pay Schedule custom field is malfigured")
    end

    @values.push(@user.team.try(:name) || "") # Department Code (OPTIONAL)
    @values.push(@user.location.try(:name) || "") # Location Code (OPTIONAL)
    @values.push("") # Division Code (OPTIONAL)

    birthday = Date.parse(get_custom_field_value_text(@user, "Date Of Birth")).strftime('%m/%d/%Y') rescue nil
    if birthday
      @values.push(birthday) # Date of Birth
    else
      @errors.push("user does not have date of birth, or date of birth field is malfigured")
    end

    gender = get_custom_field_value_text(@user, "gender")[0].try(:upcase) rescue nil

    if gender && ["M", "F"].include?(gender)
      @values.push(gender) # Gender
    else
      @errors.push("user must have a gender of Male or Female")
    end

    # Address Columns (all required)
    address_components = get_address_field_values(@user)
    # sub custom fields
    if !address_components
      @errors.push("Could not locate Address Custom Field")
    else
      if address_components.size == 5
        @values.push(address_components[:line1]) # Home Address1
        @values.push(address_components[:line2]) # Home Address2
        @values.push(address_components[:city]) # City
        @values.push(address_components[:state]) # State
        @values.push(address_components[:zip]) # Zip
      else
        @errors.push("user does not have complete Address")
      end
    end

    @values.push(get_formatted_phone_value(@user, "Home Phone Number") || "") # Home Phone (OPTIONAL)
    @values.push(get_formatted_phone_value(@user, "Mobile Phone Number") || "") # Home Phone (OPTIONAL)
    @values.push(@user.email) # Work e-mail
    @values.push(@user.personal_email || "") # Alternate e-mail (OPTIONAL)
    @values.push(@user.email) # User Name

    @values.push(@integration.bswift_auto_enroll ? 1 : 0)  # Auto enroll

    if !@errors.empty?
      LoggingService::IntegrationLogging.new.create(@company, 'BSwift', "user #{@user.id} #{@user.email}", nil, @errors.to_json, 500)
      return -1
    else
      @values
    end
  end

  private

  def get_formatted_phone_value(user, field_name)
    area_code = user.get_custom_field_value_text(field_name, false, "Area code")
    phone = user.get_custom_field_value_text(field_name, false, "Phone")
    if area_code && phone && area_code.length == 3 && phone.length == 7
      "#{area_code}-#{phone[0..2]}-#{phone[3..-1]}"
    else
      nil
    end
  end

  def get_address_field_values(user)
    {
      line1: user.get_custom_field_value_text("Home Address", false, "Line 1"),
      line2: user.get_custom_field_value_text("Home Address", false, "Line 2"),
      city: user.get_custom_field_value_text("Home Address", false, "City"),
      state: user.get_custom_field_value_text("Home Address", false, "State"),
      zip: user.get_custom_field_value_text("Home Address", false, "Zip")
    }
  end

  def get_custom_field_value_text(user, field_name)
    field = @company.custom_fields.find_by("custom_fields.name ILIKE ?", field_name.downcase)
    if field.try(:custom_table_id).present?
      get_custom_table_field_value_text(user, field)
    else
      user.get_custom_field_value_text(field_name, false, nil, field)
    end
  end

  def get_custom_table_field_value_text(user, field)
    field_value = field.custom_table.custom_table_user_snapshots.where(user_id: user.id, state: 1).includes(:custom_snapshots).find_by(custom_snapshots: {custom_field_id: field.id}).custom_snapshots.find_by(custom_field_id: field.id).custom_field_value rescue nil
    if field.field_type == "currency"
      field_value.split("|")[1] rescue nil
    elsif field.field_type == "mcq"
      field.custom_field_options.find_by(id: field_value).option rescue nil
    else
      field_value
    end
  end

  def get_employee_id_field_value
    mapped_field_name = employee_id_custom_mapping[@company.domain.to_sym]
    mapped_field_name ? get_custom_field_value_text(@user, mapped_field_name) : @user.id.to_s
  end

  def employee_id_custom_mapping
    {
      'emersoncollective.saplingapp.io': 'ADP Payroll ID'
    }
  end

  def date_converter(identifier)
    ct = @company.custom_tables.where(custom_table_property: identifier)&.take
    if @user.sent_to_bswift && ct.present? 
      value = @user.custom_table_user_snapshots.where(custom_table_id: ct.id, state: 'applied')&.take&.effective_date
      value.present? ? value.strftime('%m/%d/%Y') : @user.start_date.strftime('%m/%d/%Y')
    else
      @user.start_date.strftime('%m/%d/%Y')
    end 
  end

end
