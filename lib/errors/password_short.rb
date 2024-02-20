module Errors
  class PasswordShort < Base
    attr_reader :details

    def initialize(exception_message)
      @details = exception_message
    end

    def status
      '457'
    end

    def title
      I18n.t('errors.password_short')
    end
  end
end
