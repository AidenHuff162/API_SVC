module Interactions
  module Integrations
    class ReceiveEmployeesProfileImageFromNamely
      def perform
        Company.joins(:integrations).where(companies: {deleted_at: nil}, integrations: {api_name: :namely}).try(:find_each) do |company|
          UpdateSaplingDepartmentsAndLocationsFromNamelyJob.perform_later(nil, company)
          ReceiveUpdatedEmployeePictureFromNamelyJob.perform_later(company)
        end
      end
    end
  end
end