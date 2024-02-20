module SaplingApiService
  class ManagePendingHireValidations
    attr_reader :company

    VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
    VALID_DATE_REGEX = /^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1])$/

    def initialize(company)
      @company = company
    end

    def validateEmail(key, params, pending_hire)
      return unless [ 'personal_email' ].include?(key)

      return { message: "Attribute (#{key}), can't be blank.", status: 400 } if params[key].blank?
      return { message: "Attribute (#{key}), email format is invalid.", status: 400 } if VALID_EMAIL_REGEX.match(params[key]).blank?

      if pending_hire.blank? && (company.users.where("(personal_email ILIKE ? OR email ILIKE ?)", params[key], params[key]).present? || 
        company.pending_hires.where("personal_email ILIKE ?", params[key]).present?)
        return { message: "Attribute (#{key}), email already exists for another user/pending hire.", status: 400 }
      end

      if pending_hire.present? && (company.users.where("(personal_email ILIKE ? OR email ILIKE ?) AND id != ?", params[key], params[key], pending_hire.id).present? || 
        company.pending_hires.where("personal_email ILIKE ? AND id != ?", params[key], pending_hire.id).present?)
        return { message: "Attribute (#{key}), email already exists for another user/pending hire.", status: 400 }
      end
    end

    def validateNames(key, params)
      return unless [ 'first_name', 'last_name' ].include?(key)
      return { message: "Attribute(#{key}) can't be blank.", status: 400 } if params.has_key?(key) && params[key].blank?
    end

    def validateSource(key, params)
      return unless [ 'source' ].include?(key)
      return { message: "Attribute(#{key}) can't be blank.", status: 400 } if params.has_key?(key) && params[key].blank?
    end

    def validateDate(key, params)
      if [ 'start_date' ].include?(key)
        return { message: "Attribute (#{key}), value is required.", status: 400 } if params[key].blank? && key == 'start_date'
        
        if params[key].present? && VALID_DATE_REGEX.match(params[key]).blank?
          return { message: "Attribute (#{key}), format is invalid. It should be in format yyyy-mm-dd.", status: 400 }
        end

        if params[key].present? && !(Date.strptime(params[key], '%Y-%m-%d') rescue false).present?
          return { message: "Attribute (#{key}), value is invalid.", status: 400 }
        end
      end
    end

    def validateStatus(key, params)
      return unless key == 'status'
      return { message: "Attribute (#{key}), value is invalid.", status: 400 } if params[key].present? && !(['active', 'inactive'].include? params[key])
    end

    def validateOption(key, params)
      if key == 'location'
        location = company.locations.find_by(name: params[key]) if params[key].present?
        return { message: "Attribute (#{key}), value is invalid.", status: 400 } if params[key].present? && location.blank?

      elsif key == 'department'
        department = company.teams.find_by(name: params[key]) if params[key]
        return { message: "Attribute (#{key}), value is invalid.", status: 400 } if params[key].present? && department.blank?

      elsif key == 'employment_status'
        custom_field_option = company.custom_fields.where(name: 'Employment Status').take&.custom_field_options&.find_by(option: params[key]) if params[key].present?
        return { message: "Attribute (#{key}), value is invalid.", status: 400 } if params[key].present? && custom_field_option.blank?
      end
    end

    def validateManager(key, params)
      return unless key == 'manager'
      if params[key].present?
        manager = company.users.find_by(email: params[key]) rescue nil
        return { message: "Attribute (#{key}), no user exist in company from this email.", status: 400 } unless manager.present?
      end
    end
  end
end