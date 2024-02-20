module Errors
  class InvalidEmailPassword < Base
    def status
      '455'
    end

    def title
      I18n.t('errors.invalid_email_password')
    end

    def details
      I18n.t('errors.details.bad_email_password')
    end
  end
end
