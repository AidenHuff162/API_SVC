module Interactions
  module Integrations
    class PullEmployeesFromAdpWorkforceNow
      def perform        
        Company.where(deleted_at: nil).try(:find_each) do |company|
          if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| company.integration_types.include?(api_name) }.present?
            ReceiveUpdatedEmployeeFromAdpWorkforceNowJob.perform_later(company.id)
          end
        end
      end
    end
  end
end
