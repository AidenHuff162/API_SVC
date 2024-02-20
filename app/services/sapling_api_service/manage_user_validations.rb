module SaplingApiService
  class ManageUserValidations
    attr_reader :company

    VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
    VALID_DATE_REGEX = /^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1])$/
    ADDRESS_SUB_FIELDS = [ 'line_1', 'line_2', 'city', 'country', 'state', 'zip']
    PHONE_SUB_FIELDS = [ 'area_code', 'phone', 'country' ]
    CURRENCY_SUB_FIELDS = [ 'currency_type', 'currency_value']


    def initialize(company)
      @company = company
    end

    def validateEmail(key, params, user)
      return unless ['company_email', 'personal_email'].include?(key)
      return { message: "Can not update. Attribute(#{key}) is required", status: 400 } if !params[key].present? && key == 'company_email'
      return { message: "Can not update. Attribute(#{key}) email is invalid", status: 400 } if !VALID_EMAIL_REGEX.match(params[key]).present?
      return { message: "Can not update. Email already exists for another user for attribute(#{key})", status: 400 } if user.present? && company.users.where("(personal_email ILIKE ? OR email ILIKE ?) AND id != ?", params[key], params[key], user.id).present?
      return { message: "Can not update. Email already exists for another user for attribute(#{key})", status: 400 } if company.users.where("(personal_email ILIKE ? OR email ILIKE ?)", params[key], params[key]).present? && !user.present?
    end

    def validateDate(key, params, api_field_ids = nil)
      if ['start_date', 'termination_date', 'last_day_worked'].include?(key)
        return { message: "Can not update. Attribute(#{key}) value is required", status: 400 } if !params[key].present? && key == 'start_date'
        if params[key].present? && !VALID_DATE_REGEX.match(params[key])
          return { message: "Can not update. Attribute(#{key}) format is invalid. It should be in foramt yyyy-mm-dd", status: 400 }
        end

        if params[key].present? && !(Date.strptime(params[key], '%Y-%m-%d') rescue false).present?
          return { message: "Can not update. Attribute(#{key}) value is invalid.", status: 400 }
        end

      elsif api_field_ids.present? && api_field_ids.include?(key)
        if params[key].present? && !VALID_DATE_REGEX.match(params[key])
          return { message: "Can not update. Attribute(#{key}) format is invalid. It should be in foramt yyyy-mm-dd", status: 400 }
        end

        if params[key].present? && !(Date.strptime(params[key], '%Y-%m-%d') rescue false).present?
          return { message: "Can not update. Attribute(#{key}) value is invalid.", status: 400 }
        end
      end
    end

    def validateGuid(key, params, coworker_fields_parent_set = nil, user)
      if coworker_fields_parent_set.present? && coworker_fields_parent_set.include?(key)
        return { message: "User doesnot exits for attribute(#{key})", status: 400 } if params[key].present? && !company.users.find_by(guid: params[key]).present?
      elsif key == 'manager'
        return { message: "User cannot be a manager of himself", status: 400 } if user.present? && user.guid == params[key]
        return { message: "User doesnot exits for attribute(#{key})", status: 400 } if params[key].present? && !company.users.find_by(guid: params[key]).present?
      end
    end

    def validateOption(key, params, options_fields_parent_set)
      if key == 'location'
        location = company.locations.find_by(name: params[key]) if params[key].present?
        return { message: "Location doesnot exits for attribute(#{key}) value", status: 400 } if params[key].present? && !location.present?

      elsif key == 'department'
        department = company.teams.find_by(name: params[key]) if params[key]
        return { message: "Department doesnot exits for attribute(#{key}) value", status: 400 } if params[key].present? && !department.present?

      elsif options_fields_parent_set.present? && options_fields_parent_set.pluck(:api_field_id).include?(key)
        custom_field = options_fields_parent_set.find_by(api_field_id: key)
        custom_field_option = custom_field.custom_field_options.find_by(option: params[key])
        return { message: "Invalid Value for attribute(#{key})", status: 400 } if params[key].present? && !custom_field_option.present?
      end
    end

    def validateStatus(key, params)
      return unless key == 'status'
      return { message: "Invalid Value for attribute(#{key})", status: 400 } if params[key].present? && !(['active', 'inactive'].include? params[key])
    end

    def validateSSN(key, params, ssn_parent_set)
      if ssn_parent_set.present? && ssn_parent_set.include?(key)
        return { message: "Invalid SSN Value for attribute(#{key})", status: 400 } if params[key].present? && !params[key].match(/^\d{3}-\d{2}-\d{4}$/)
      end
    end

    def validateSIN(key, params, sin_parent_set)
      if sin_parent_set.present? && sin_parent_set.include?(key)
        return { message: "Invalid SIN Value for attribute(#{key})", status: 400 } if params[key].present? && !params[key].match(/^\d{3}-\d{3}-\d{3}$/)
      end
    end

    def validateNames(key, params)
      return unless ['first_name', 'last_name'].include?(key)
      return { message: "Can not update. Attribute(#{key}) value is required", status: 400 } if params.has_key?(key) && !params[key].present?
    end

    def validateAddress(key, params)
      begin
        params[key] = parse_sub_fields(params[key])
        params.permit!
      rescue
        return { message: "Invalid Value for attribute(#{key})", status: 400 }
      end

      return { message: "Hash members are required for attribute(#{key})", status: 400 } if !params[key].present?
      params[key].each do |key, value|
        sub_custom_field = ADDRESS_SUB_FIELDS.include?(key)
        return { message: "Invalid Hash key for attribute(#{key})", status: 400} if !sub_custom_field.present?
      end

      begin
        country = Country.where("lower (name) = ?", params[key]["country"].to_s.downcase).take
        raise 'Invalid format' if params[key]["country"].present? && !country.present?
        raise 'Invalid format' if params[key]["state"].present? && country.present? && !country.states.where("lower (name) = ?", params[key]["state"].to_s.downcase).present?
      rescue
        return { message: "Invalid Value for attribute(#{key})", status: 400 }
      end

      return nil
    end

    def validateInternationPhone(key, params)
      begin
        params[key] = parse_sub_fields(params[key])
        params.permit!
      rescue
        return { message: "Invalid Value for attribute(#{key})", status: 400 }
      end

      return { message: "Hash members are required for attribute(#{key})", status: 400 } if !params[key].present?
      params[key].each do |key, value|
        sub_custom_field = PHONE_SUB_FIELDS.include?(key)
        return { message: "Invalid Hash key for attribute(#{key})", status: 400} if !sub_custom_field.present?
      end

      begin
        country_code = ISO3166::Country.find_country_by_alpha3(params[key]['country']).country_code
        phone = Phonelib.parse("+#{country_code}-#{params[key]['area_code']}-#{params[key]['phone']}")
        raise 'Invalid format' if !Phonelib.valid_for_country? phone, phone.country
      rescue Exception => se
        return { message: "Invalid Value for attribute(#{key})", status: 400 }
      end
      return nil
    end

    def validateCurrency(key, params)
      begin
        params[key] = parse_sub_fields(params[key])
        params.permit!
      rescue
        return { message: "Invalid Value for attribute(#{key})", status: 400 }
      end

      return { message: "Hash members are required for attribute(#{key})", status: 400 } if !params[key].present?
      params[key].each do |key, value|
        sub_custom_field = CURRENCY_SUB_FIELDS.include?(key)
        return { message: "Invalid Hash key for attribute(#{key})", status: 400} if !sub_custom_field.present?
      end

      begin
        Money.new(params[key]['currency_value'], params[key]['currency_type'])
      rescue Money::Currency::UnknownCurrency => se
        render json: { message: "Invalid Currency Value for attribute(#{key})" }, status: 400
      end

      return nil
    end

    def validateNumber(key, params)
      return { message: "Invalid Value for attribute(#{key})", status: 400 } if params[key].present? && !params[key].match(/^[0-9]*$/)
    end

    def validateFile(key, params)
      uploaded_file = nil
      begin
        if params[key].try(:tempfile)
          file = params[key].tempfile
        else
          decode_base64_content = Base64.decode64(params[key])
          tempfile = "tmp/#{DateTime.now.strftime("%Q")}.png"
          File.open(tempfile, "wb"){|f|  f.write(decode_base64_content) }
          file = File.open(tempfile)
        end
        uploaded_file = UploadedFile.create(file: file, type: "UploadedFile::ProfileImage",
            company_id: company.id, original_filename: 'Profile Image')
        raise 'Invalid format' if !uploaded_file.file.present?
      rescue Exception => se
         return { message: "profile image is not valid", status: 400 }
      end

      return uploaded_file
    end

    private

    # expects input to be a key-value string.
    # @param [String] input
    # @return [Hash]
    # @raise [Psych::SyntaxError] if unparseable input
    # @raise [StandardError] if the parsed input is not a Hash
    # @raise [ArgumentError] if input is nil
    def parse_sub_fields(input)
      raise ArgumentError, 'does not accept a nil input' if input.nil?

      # YAML parser is more flexible than a JSON parser because it can handle unquoted keys. However, it's necessary
      # to ensure the key values are correctly spaced
      fixed_input = input.gsub(/[:](?<=[^ ])/, ': ')
      result = YAML.safe_load(fixed_input)

      raise StandardError, 'input does not contain valid sub-field format' unless result.is_a?(Hash)

      result
    end
  end
end
