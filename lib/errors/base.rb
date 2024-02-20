module Errors
  class Base
    def self.error
      self.new.error
    end

    def error
      @error ||= {
        status: status,
        title: title,
        details: details
      }
    end

    def status
      fail(NotImplementedError)
    end

    def title
      fail(NotImplementedError)
    end

    def details
      fail(NotImplementedError)
    end
  end
end
