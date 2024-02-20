module Errors
  class InvalidNamelyCredentials < Base
    def status
      '404'
    end

    def title
      I18n.t('errors.invalid_namely_credentials')
    end

    def details
      I18n.t('errors.invalid_namely_credentials')
    end
  end
end
