module Interactions
  module Integrations
    class UpdateSaplingDepartmentsAndLocationsFromAdpWorkforceNow
      def perform
        Company.where(deleted_at: nil).try(:find_each) do |company|
          UpdateSaplingDepartmentAndTeamFromNamelyForCruiseJob.perform_later(company) if company.subdomain.eql?('cruise')
        end
      end
    end
  end
end
