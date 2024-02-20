module Errors
  class InvalidToken < Base
    def status
      '456'
    end

    def title
      I18n.t('errors.invalid_token')
    end

    def details
      I18n.t('errors.details.invalid_token')
    end
  end
end
