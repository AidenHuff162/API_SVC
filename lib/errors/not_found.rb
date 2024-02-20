module Errors
  class NotFound < Base
    attr_reader :details

    def initialize(exception_message)
      @details = exception_message
    end

    def status
      '404'
    end

    def title
      I18n.t('errors.not_found')
    end
  end
end
