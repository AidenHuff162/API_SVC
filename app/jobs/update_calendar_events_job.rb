class UpdateCalendarEventsJob
	include Sidekiq::Worker
	sidekiq_options queue: :default

  def perform args
    if args["create_events"]
      CreateExistingCalendarEventsService.new(args["company_id"]).perform
    else
      RemoveExistingCalendarEventsService.new(args["company_id"]).perform
    end
  end
end
