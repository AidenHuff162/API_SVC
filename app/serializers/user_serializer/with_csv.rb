module UserSerializer
  class WithCSV < Base
    attributes :id, :title, :role, :state, :email, :last_activity_at, :start_date,
               :team, :location, :manager, :buddy, :outstanding_tasks_count, :employee_type, :termination_date,
               :personal_email, :incomplete_documents_count, :about_you, :facebook_url, :twitter_url,
               :linkedin_url, :github_url

    def attributes(*attrs)
      data = super
      object.custom_field_values.each do |field|
        if field.custom_field && field.custom_field.field_type == 'mcq' && field.custom_field_option_id
          value = CustomFieldOption.find_by(id: field.custom_field_option_id).option
          data[:"custom_#{field.custom_field.name.parameterize.underscore}"] = value
        elsif field.custom_field && field.custom_field.field_type == 'confirmation'
          if field.value_text == 't' || field.value_text == 'true'
            data[:"custom_#{field.custom_field.name.parameterize.underscore}"] = 'true'
          elsif field.value_text == 'f' || field.value_text == 'false'
            data[:"custom_#{field.custom_field.name.parameterize.underscore}"] = 'false'
          else
            data[:"custom_#{field.custom_field.name.parameterize.underscore}"] = nil
          end
        else
          data[:"custom_#{field.custom_field.name.parameterize.underscore}"] = field.value_text if field.custom_field && field.custom_field.name && field.value_text
        end
      end
      data
    end

    def incomplete_documents_count
      object.incomplete_upload_request_count + object.incomplete_paperwork_count + object.co_signer_paperwork_count
    end

    def about_you
      object.profile.about_you if object.profile
    end

    def facebook_url
      object.profile.facebook if object.profile
    end

    def twitter_url
      object.profile.twitter if object.profile
    end

    def linkedin_url
      object.profile.linkedin if object.profile
    end

    def github_url
      object.profile.github if object.profile
    end

    def team
      object.team.name if object.team
    end

    def location
      object.location.name if object.location
    end

    def manager
      object.manager.full_name if object.manager
    end

    def buddy
      object.buddy.full_name if object.buddy
    end

    def name
      object.full_name
    end

    def last_activity_at
      if object.offboarding?
        I18n.t('models.user.last_activity_at.offboarding')
      elsif object.departed?
        I18n.t('models.user.last_activity_at.offboarded')
      elsif object.incomplete?
        I18n.t('models.user.last_activity_at.incomplete')
      elsif object.invited?
        I18n.t('models.user.last_activity_at.invited')
      elsif object.preboarding?
        I18n.t('models.user.last_activity_at.preboarding')
      elsif object.onboarding?
        I18n.t('models.user.last_activity_at.onboarding')
      elsif object.registered? && object.last_sign_in_at.blank?
        I18n.t('models.user.last_activity_at.no_activity')
      else
        object.last_sign_in_at.try(:strftime,'%d-%b-%Y')
      end
    end

    def employee_type
      object.employee_type
    end
  end
end
