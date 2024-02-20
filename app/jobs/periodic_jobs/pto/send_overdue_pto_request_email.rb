module PeriodicJobs::Pto
  class SendOverduePtoRequestEmail
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Pto::SendOverduePtoRequestEmail').ping_start
      
      PtoRequest.includes(pto_policy: :company).overdue_requests.find_each do |request|
        if request.begin_date > request.pto_policy.company.time.to_date && request.pto_policy.company.account_state == "active"
          ::TimeOff::SendOverdueRequestsEmailJob.perform_later(request.id)
        end
      end
      
      HealthCheck::HealthCheckService.new('PeriodicJobs::Pto::SendOverduePtoRequestEmail').ping_ok
    end
  end
end
