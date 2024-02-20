module Errors
  class Unauthorized < Base
    def status
      '401'
    end

    def title
      I18n.t('errors.unauthorized')
    end

    def details
      I18n.t('devise_token_auth.sessions.bad_credentials')
    end
  end
end
