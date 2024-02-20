module Errors
  class BadRequest < Base
    attr_reader :details

    def initialize(exception_message)
      @details = exception_message
    end

    def status
      '400'
    end

    def title
      I18n.t('errors.bad_request')
    end
  end
end
