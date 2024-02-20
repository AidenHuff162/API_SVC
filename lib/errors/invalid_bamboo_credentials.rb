module Errors
  class InvalidBambooCredentials < Base
    def status
      '404'
    end

    def title
      I18n.t('errors.invalid_bamboo_credentials')
    end

    def details
      I18n.t('errors.invalid_bamboo_credentials')
    end
  end
end
