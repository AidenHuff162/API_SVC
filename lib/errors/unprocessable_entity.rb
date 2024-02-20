module Errors
  class UnprocessableEntity < Base
    def initialize(entity)
      add_messages(entity)
    end

    def status
      '422'
    end

    def title
      I18n.t('errors.unprocessable_entity')
    end

    def details
      I18n.t('errors.record_invalid')
    end

    private

    def add_messages(entity)
      error[:messages] = entity.errors.full_messages
    end
  end
end
