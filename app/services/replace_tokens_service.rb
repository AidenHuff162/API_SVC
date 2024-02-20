class ReplaceTokensService
  def create_hyperlink token_value, user
    link = "https://#{user.company.app_domain}/#/profile/#{user.id}"
    " <a href=\"#{link}\" target=\"_blank\">#{CGI.escapeHTML(token_value)}</a> "
  end

  def fetch_token_value (token, object, tasks_count = nil, activity_owner = nil, document = nil, cf_id = nil, is_subject = false, pto_request = nil)
      unless object.present?
        return ''
      end

      token = token[0..-2] if !token.is_a?(Numeric) && token[-1, 1].ord == 8204
      case token
      when 'Paylocity ID'
        object&.paylocity_id.to_s
      when 'Hire First Name', 'First Name'
        object.try(:first_name).present? ? object.first_name : ""
      when 'Hire Last Name', 'Last Name'
        object.try(:last_name).present? ? object.last_name : ""
      when 'Hire Preferred/ First Name', 'Preferred/ First Name'
        object.try(:preferred_name).present? ? object.preferred_name : object.first_name
      when 'Hire Full Name', 'Full Name'
        if is_subject
          "#{object.preferred_full_name}"
        else
          token_value = "#{object.preferred_full_name}"
          return (create_hyperlink token_value, object), true
        end
      when 'Hire Title', 'Job Title'
        object.title
      when "#{object&.company&.buddy} First Name"
        if object.try(:buddy).present?
          object.buddy.try(:first_name).present? ? object.buddy.first_name : ""
        else
          ''
        end
      when "#{object&.company&.buddy} Preferred/ Full Name", "#{object&.company&.buddy} Full Name"
        if object.try(:buddy).present?
          if is_subject
            "#{object.buddy.preferred_full_name}"
          else
            token_value = "#{object.buddy.preferred_full_name}"
            return (create_hyperlink token_value, object.buddy), true
          end
        else
          ''
        end
      when "#{object&.company&.buddy} Title"
        object.try(:buddy).present? ? object.buddy.title : ''
      when "#{object&.company&.buddy} Department"
        object.try(:buddy).present? && object.buddy.team.present? ? object.buddy.team.name : ''
      when "#{object&.company&.buddy} Location"
        object.try(:buddy).present? && object.buddy.location.present? ? object.buddy.location.name : ''
      when "#{object&.company&.buddy} Email"
        object.try(:buddy).present? ? object.buddy.get_present_email : ''
      when 'Manager First Name'
        if object.manager.present?
          object.manager.first_name.present? ? object.manager.first_name : ""
        else
          ''
        end
      when 'Manager Preferred/ Full Name', 'Manager Full Name'
        if object.manager.present?
          if is_subject
            "#{object.manager.preferred_full_name}"
          else
            token_value = "#{object.manager.preferred_full_name}"
            return (create_hyperlink token_value, object.manager), true
          end
        else
          ''
        end
      when 'Manager Title'
        object.manager.present? ? object.manager.title : ''
      when 'Manager Email'
        object.manager.present? ? object.manager.get_present_email : ''
      when 'Manager Department'
        object.manager.present? && object.manager.team.present? ? object.manager&.team.name : ''
      when 'Manager Location'
        object.manager.present? && object.manager.location.present? ? object.manager&.location.name : ''
      when "Hire #{object&.company&.department.try(:singularize)}", "#{object&.company&.department.try(:singularize)}"
        object.team.present? ? object.team.name : ''
      when 'Hire Location', 'Location'
        object.location.present? ? object.location.name : ''
      when 'Hire Start Date', 'Start Date', 'Current Start Date', 'New Start Date'
        with_company_format(object.try(:start_date), object.try(:company))
      when 'Old Start Date'
        with_company_format(object.try(:old_start_date), object.try(:company))
      when 'Task Owner First Name' , 'Activity Owner First Name'
        if activity_owner.present?
          activity_owner.preferred_name.present? ? activity_owner.preferred_name : activity_owner.first_name
        else
          ''
        end
      when 'Task Count' , 'Activity Count'
        tasks_count
      when 'Task Owner Email', 'Activity Owner Email'
        activity_owner.present? ? activity_owner.get_present_email : ''
      when 'Account Creator Email'
        object.try(:account_creator).present? ? object.account_creator.get_present_email : ''
      when 'Account Creator First Name'
        if object.try(:account_creator).present?
          object.account_creator.preferred_name.present? ? object.account_creator.preferred_name : object.account_creator.first_name
        else
          ''
        end
      when 'Company Name'
        object.company.present? ? object.company.name  : ''
      when 'Document Name'
        document.present? ? document.title : ''
      when 'Termination Date'
        with_company_format(object.try(:termination_date), object.try(:company))
      when 'Personal Email'
        object.personal_email.present? ? object.personal_email : ''
      when 'Company Email'
        object.email.present? ? object.email : ''
      when 'Employment Status'
        object.employee_type.present? ? object.employee_type.try(:titleize) : ''
      when 'Last Day Worked', 'Last Day'
        with_company_format(object.try(:last_day_worked), object.try(:company))
      when 'Access Permission'
        object.try(:user_role).present? ? object.user_role&.name : ''
      when 'Status'
        object.try(:state).present? ? object.state : ''
      when 'Termination type'
        object.try(:termination_type).present? ? object.termination_type.titleize : ''
      when 'Eligible for Rehire'
        object.try(:eligible_for_rehire).present? ? object.eligible_for_rehire.sub('_',' ').titleize : ''
      when 'About'
        object.profile.try(:about_you).present? ? object.profile.about_you : ''
      when 'Facebook'
        object.profile.try(:facebook).present? ? object.profile.facebook : ''
      when 'LinkedIn'
        object.profile.try(:linkedin).present? ? object.profile.linkedin : ''
      when 'Twitter'
        object.profile.try(:twitter).present? ? object.profile.twitter : ''
      when 'Github'
        object.profile.try(:github).present? ? object.profile.github : ''
      when 'Display Name'
        if is_subject
          "#{object.display_name}"
        else
          token_value = "#{object.display_name}"
          return (create_hyperlink token_value, object), true
        end
      when 'Policy Name'
        pto_request.present? && pto_request.pto_policy.present? ? pto_request.pto_policy.name : 'Policy'
      else
        id = cf_id.present? ? cf_id : token
        custom_field = CustomField.find_by(id: id)
        return ' ' if custom_field.nil?
        if object.class.name == "PendingHire"
          return fetch_pending_hire_custom_field(custom_field, object)
        end
        if custom_field.field_type == 'phone'
          country, area_code, phone = custom_field.phone_field_values(object.id)
          if country.present? && area_code.present? && phone.present?
            country = ISO3166::Country.find_country_by_alpha3(country)&.country_code rescue nil
            return "+#{country} #{area_code}-#{phone[0..2]}-#{phone[3..-1]}"
          else
            return ' '
          end
        elsif custom_field.field_type == "address"
          address = object.get_custom_field_value_text(nil, true, nil, nil, false, custom_field.id)
          if address
            return_string = address[:line1].present? ? "<br>#{address[:line1]}" : ""
            return_string += "<br>#{address[:line2]}" if address[:line2].present? 
            return_string += "<br>"
            return_string += "#{address[:city]}, " if address[:city].present?
            return_string += "#{address[:state]}, " if address[:state]
            return_string += "#{address[:zip]}" if address[:zip]
            return_string += "<br>"
            return_string += "#{address[:country]}<br>" if address[:country]
            return return_string
          else
            return ' '
          end
        elsif CustomField.typehHasSubFields(custom_field.field_type)
          return_values = custom_field.sub_custom_fields.order(:id).map do |sub_custom_field|
            CustomField.get_sub_custom_field_value(custom_field, sub_custom_field.name, object.id)
          end
          return " #{return_values.join(', ')} "
        elsif custom_field.field_type == 'mcq'
          value = CustomField.get_mcq_custom_field_value(custom_field, object.id)
          return value.present? ?  value : ' '

        elsif custom_field.field_type == 'multi_select'
          value = CustomField.get_multiselect_custom_field_value(custom_field, object.id)
          return value.present? ?  value : ' '

        elsif custom_field.field_type == 'coworker'
          value = CustomField.get_coworker_value(custom_field,object.id)

          if value.present?

            if token.eql?("#{custom_field.name} First Name")
              return value.first_name.present? ? value.first_name : ""

            elsif token.eql?("#{custom_field.name} Title")
              return value.title.present? ? value.title : ' '

            elsif token.eql?("#{custom_field.name} Email")
              return value.email.present? ? value.email : ' '

            elsif token.eql?("#{custom_field.name} Department")
              return value.get_team_name.present? ? value.get_team_name : ' '

            elsif token.eql?("#{custom_field.name} Location")
              return value.get_location_name.present? ? value.get_location_name : ' '

            elsif token.eql?("#{custom_field.name} Preferred/ Full Name")
              if is_subject
                return value.preferred_full_name
              else
                return (create_hyperlink value.preferred_full_name, value), true
              end
            end

          end
        else
          value = object.get_custom_field_value_text(custom_field.name, false, nil, custom_field)
          return with_company_format(value.try(:to_date), object.try(:company)) if custom_field.field_type == 'date'
          return value.present? ?  value : ' '
        end
      end

    end

  def fetch_pending_hire_custom_field(custom_field, pending_hire)
    if (pending_hire.source == 'green_house' || (pending_hire.company.ats_integration_types.count == 1 && pending_hire.company.ats_integration_types.include?('green_house')))
      return pending_hire.custom_fields[custom_field.ats_mapping_section]["custom_fields"][custom_field.ats_mapping_key]["value"] rescue ' '
    else
      return ' '
    end
  end

  def replace_tokens (string, object, tasks_count = nil, activity_owner = nil, document = nil, is_subject = false, pto_request = nil, escape_html = true)
    replace_task_tokens(string, object, tasks_count, activity_owner, document, is_subject, pto_request, escape_html)
  end

  def replace_task_tokens (string, object, tasks_count = nil, activity_owner = nil, document = nil, is_subject = false, pto_request = nil, escape_html = true)
    token_exists = false
    noko = Nokogiri::HTML(string)
    xpath = "//*[@class='token']"
    nodes = noko.xpath(xpath)

    nodes.each do |node|
      next unless node.children.present?
      token_exists = true
      cf_id = node.attributes["data-name"].value
      token_value, noneed_esp = fetch_token_value(node.children.text, object, tasks_count, activity_owner, document, cf_id, is_subject, pto_request)
      if noneed_esp || token_value.nil?
        node.content = token_value
      else
        token_value = token_value.to_s.gsub("\u0000", "")
        node.content = escape_html ? CGI.escapeHTML(token_value.to_s) : token_value.to_s
      end
      node.replace(node.content)
    end
    if token_exists
      return noko.xpath("//body").try(:children).to_s
    else
      return string
    end
  end

  def fetch_dummy_token_value token, company
    token = token[0..-2] if !token.is_a?(Numeric) && token[-1, 1].ord == 8204
    case token
    when 'Hire First Name', 'First Name'
      'Liz'
    when 'Hire Last Name', 'Last Name'
      'Lemon'
    when 'Hire Preferred/ First Name', 'Preferred/ First Name'
      'Liz'
    when 'Hire Full Name', 'Full Name'
      'Elizabeth Lemon'
    when 'Hire Title', 'Job Title'
      'Creative Director'
    when "#{company&.buddy} First Name"
      'Tracy'
    when "#{company&.buddy} Full Name"
      'Tracy Jordan'
    when "#{company&.buddy} Title"
      'Lead Engineer'
    when "#{company&.buddy} Email"
      'tjordan@gmail.com'
    when "#{company&.buddy} Department"
      'Engineering'
    when "#{company&.buddy} Location"
      'New York City'
    when 'Manager First Name'
      'Jack'
    when 'Manager Full Name'
      'Jack Donaghy'
    when 'Manager Title'
      'Vice President'
    when 'Manager Email'
      'jackattack@gmail.com'
    when "Hire #{company&.department}", "#{company&.department}" , 'Manager Department'
      'Marketing'
    when 'Hire Location', 'Location' , 'Manager Location'
      'New York City'
    when 'Hire Start Date', 'Start Date', 'Current Start Date', 'New Start Date', 'Termination Date', 'Last Day Worked', 'Last Day'
      with_company_format(Date.today(), company)
    when 'Old Start Date'
      with_company_format(3.days.ago, company)
    when 'Personal Email'
      'liz.personal@test.com'
    when 'Company Email'
      'liz@test.com'
    when 'Employment Status'
      'full_time'.try(:titleize)
    when 'Termination type'
      'volunteer'
    when 'Eligible for Rehire'
      'No'
    when 'About'
      "Best Person"
    when 'Facebook'
      'Facebook link'
    when 'LinkedIn'
      'LinkedIn Link'
    when 'Twitter'
      'Twitter Link'
    when 'Github'
      'Github link'
    when 'Company Name'
      company.name || 'Dummy value'
    else
       'Dummy value'
    end
  end

  def replace_dummy_tokens string, company
    token_exists = false
    company_department = company && company.department.present? ? company.department : 'Department'
    noko = Nokogiri::HTML(string)
    email_templates = EMAIL_TOKENS.dup
    email_templates.push("#{company&.buddy} First Name") unless email_templates.include?("#{company&.buddy} First Name")
    email_templates.push("#{company&.buddy} Full Name") unless email_templates.include?("#{company&.buddy} Full Name")
    email_templates.push("#{company&.buddy} Title") unless email_templates.include?("#{company&.buddy} Title")
    email_templates.push("#{company&.buddy} Email") unless email_templates.include?("#{company&.buddy} Email")
    email_templates.push("#{company&.buddy} Department") unless email_templates.include?("#{company&.buddy} Department")
    email_templates.push("#{company&.buddy} Location") unless email_templates.include?("#{company&.buddy} Location")
    email_templates.push("Hire #{company_department}") unless email_templates.include?("Hire #{company_department}")
    email_templates.push("#{company_department}") unless email_templates.include?("#{company_department}")
    fields = company.custom_fields.pluck(:id)
    fields.each do |field|
      email_templates.push(field)
    end
    email_templates.each do |email_token|
      xpath = "//*[@data-name='#{email_token}']"
      nodes = noko.xpath(xpath)
      if nodes.size > 0
        token_exists = true
        nodes.each do |node|

          node.content = fetch_dummy_token_value(email_token, company)
        end
      end
    end
    if token_exists
      return noko.xpath("//body").try(:children).to_s.gsub(/\n/ , '')
    else
      return string.gsub(/\n/ , '')
    end
  end

  private

  def with_company_format(date, company)
    TimeConversionService.new(company).perform(date) rescue ' '
  end

end
