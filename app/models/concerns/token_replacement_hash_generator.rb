module TokenReplacementHashGenerator
  extend ActiveSupport::Concern
  def getTokensHash(user)
    company = user.try(:company)
    tokensHash = {
                            "Hire Name" => user.full_name,
                            "Hire Full Name" => user.full_name,
                            "Hire First Name" => user.first_name.present? ? user.first_name : "",
                            "Hire Preferred/ First Name" => user.preferred_name.present? ? user.preferred_name : user.first_name,
                            "Hire Last Name" => user.last_name.present? ? user.last_name : "",
                            "Hire Email" => (user.personal_email || user.email),
                            "Hire Title" => user.title,
                            "Hire Location" => user.location.present? ? user.location.name : "",
                            "Hire Department" => user.team.present? ? user.team.name : "",
                            "Hire Start Date" => with_company_format(user.try(:start_date), company),
                            "Hire Manager" => user.manager.present? ? user.manager.full_name : "",
                            "Name" => user.full_name,
                            "Full Name" => user.full_name,
                            "First Name" => user.first_name.present? ? user.first_name : "",
                            "Preferred/ First Name" => user.preferred_name.present? ? user.preferred_name : user.first_name,
                            "Last Name" => user.last_name.present? ? user.last_name : "",
                            "Company Email" => user.email,
                            "Personal Email" => user.personal_email,
                            "Job Title" => user.title,
                            "Location" => user.location.present? ? user.location.name : "",
                            "Department" => user.team.present? ? user.team.name : "",
                            "Start Date" => with_company_format(user.try(:start_date), company),
                            "Current Start Date" => with_company_format(user.try(:start_date), company),
                            "Old Start Date" => with_company_format(user.try(:old_start_date), company),
                            "Employment Status" => user.try(:employee_type).try(:titleize),
                            "Last Day" => with_company_format(user.try(:last_day_worked), company),
                            "Last Day Worked" => with_company_format(user.try(:last_day_worked), company),
                            "Manager" => user.manager.present? ? user.manager.full_name : "",
                            "Manager Full Name" => user.manager.present? ? user.manager.full_name : "",
                            "Manager First Name" => user.manager.present? ? user.manager.first_name : "",
                            "Manager Last Name" => user.manager.present? ? user.manager.last_name : "",
                            "Manager Title" => user.manager.present? ? user.manager.title : "",
                            "Manager Email" => user.manager.present? ? user.manager.email.present? ? user.manager.email: user.manager.personal_email : "",
                            "Manager Department" => user.manager.present? ? user.manager.team.present? ? user.manager.team.name : "" : "",
                            "Manager Location" => user.manager.present? ? user.manager.location.present? ? user.manager.location.name : "" : "",
                            "Buddy Full Name" => user.buddy.present? ? user.buddy.full_name : "",
                            "Buddy First Name" => user.buddy.present? ? user.buddy.first_name : "",
                            "Buddy Last Name" => user.buddy.present? ? user.buddy.last_name : "",
                            "Buddy Title" => user.buddy.present? ? user.buddy.title : "",
                            "Buddy Email" => user.buddy.present? ? user.buddy.email.present? ? user.buddy.email: user.buddy.personal_email : "",
                            "Buddy Department" => user.buddy.present? ? user.buddy.first_name : "",
                            "Buddy Location" => user.buddy.present? ? user.buddy.location.present? ? user.buddy.location.name : "" : "",
                            "Termination type" => user.try(:termination_type).present? ? user.termination_type.titleize : '',
                            "Termination Date" => with_company_format(user.try(:termination_date), company),
                            "Status" => user.try(:state).present? ? user.state : '',
                            "Access Permission" => user.try(:user_role).present? ? user.user_role&.name : '',
                            "Eligible for Rehire" => user.try(:eligible_for_rehire).present? ? user.eligible_for_rehire.sub('_',' ').titleize : '',
                            "About" => user.profile.try(:about_you).present? ? user.profile.about_you : '',
                            "Facebook" => user.profile.try(:facebook).present? ? user.profile.facebook : '',
                            "LinkedIn" => user.profile.try(:linkedin).present? ? user.profile.linkedin : '',
                            "Twitter" => user.profile.try(:twitter).present? ? user.profile.twitter : '',
                            "Github" => user.profile.try(:github).present? ? user.profile.github : ''
                            }
    user.company.custom_fields.each do |custom_field|
      if custom_field
        if CustomField.typehHasSubFields(custom_field.field_type)
          if custom_field.field_type == 'address'
            address_format = ['Line 1', 'Line 2', 'City', 'State', 'Zip', 'Country']
            return_string = CustomField.get_formatted_home_address(custom_field, address_format, user.id)
          else
            value = custom_field.sub_custom_fields.order(:id).map do |sub_custom_field|
              CustomField.get_sub_custom_field_value(custom_field, sub_custom_field.name, user.id)
            end
            return_string = " #{value.compact.join(', ')} "
          end
        tokensHash.merge!(custom_field.name => return_string)

        elsif custom_field.field_type == 'mcq'
          value = CustomField.get_mcq_custom_field_value(custom_field,user.id)
          return_string = value.present? ?  value : ' '
          tokensHash.merge!(custom_field.name => return_string)

        elsif custom_field.field_type == 'coworker'
          value = CustomField.get_coworker_value(custom_field,user.id)
          return_string = value.present? ?  value.preferred_full_name : ' '
          tokensHash.merge!(custom_field.name => return_string)

        else
          value = CustomField.get_custom_field_value(custom_field,user.id)
          if custom_field.field_type == 'date'
            return_string = with_company_format(value.try(:to_date), company) rescue value
          else
            return_string = value.present? ?  value : ' '
          end
          tokensHash.merge!(custom_field.name => return_string)
        end
      end
    end
    return tokensHash
  end

  private

  def with_company_format(date, company)
    TimeConversionService.new(company).perform(date) rescue ' '
  end
end
