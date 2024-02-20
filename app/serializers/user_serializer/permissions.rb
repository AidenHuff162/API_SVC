module UserSerializer
  class Permissions < Basic
    attributes :employee_type, :title, :role, :last_activity_at

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
        now = Date.today
        if object.start_date > now
          I18n.t('models.user.last_activity_at.pre-start')
        elsif object.start_date+7 > now
          I18n.t('models.user.last_activity_at.first-week')
        elsif object.start_date+30 > now
          I18n.t('models.user.last_activity_at.first-month')
        else
          I18n.t('models.user.last_activity_at.ramping-up')
        end
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
