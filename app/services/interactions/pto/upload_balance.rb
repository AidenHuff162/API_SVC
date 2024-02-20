module Interactions
  module Pto
    class UploadBalance

      def initialize(params, current_company)
        @params = params
        @current_company = current_company
      end

      def perform
        CsvUploadTimeOffJob.perform_later(@params, @current_company)
      end
    end
  end
end
