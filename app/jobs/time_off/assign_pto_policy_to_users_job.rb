module TimeOff
  class AssignPtoPolicyToUsersJob
		include Sidekiq::Worker
    sidekiq_options queue: :pto_activities

    def perform(args)
      Pto::AssignPolicies.new.perform(PtoPolicy.find_by(id:args["policy"]))
    end

  end
end
