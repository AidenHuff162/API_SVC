module Errors
  class Forbidden < Base
    attr_reader :details

    def initialize(exception_message)
      @details = exception_message
    end

    def status
      '403'
    end

    def title
      I18n.t('errors.forbidden')
    end
  end
end
