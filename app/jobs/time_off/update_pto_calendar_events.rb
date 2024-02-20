module TimeOff
  class UpdatePtoCalendarEvents
		include Sidekiq::Worker
    sidekiq_options queue: :pto_activities
    def perform args
      pto_policy = PtoPolicy.find_by(id: args["policy"])
      pto_policy.pto_requests.where(status: PtoRequest.statuses["approved"]).try(:each) do |pto_request|
        pto_request.update_pto_event_type
      end if pto_policy
    end
  end
end
