module Interactions
  module Users
    class SetUserCurrentStage

      def perform(company)
        return unless company

        updated_record_hash = { onboarding: [], offboarding: [] }
        company.users.try(:find_each) do |user|
          begin
            if !user.invited? && !user.preboarding? && !user.incomplete?
              if user.stage_onboarding?
                user.onboarding!
                updated_record_hash[:onboarding] << user.id
              elsif user.stage_departed?
                user.offboarding!
                updated_record_hash[:offboarding] << user.id
              end
            end
          rescue Exception => e
            LoggingService::GeneralLogging.new.create(company, 'Update Current Stage- Fail', {request: "#{user.id}:#{user.full_name} SetUserCurrentStage", error: e.message})
          end
        end
        LoggingService::GeneralLogging.new.create(company, 'Update Current Stage - Complete', {data: updated_record_hash })
      end
    end
  end
end
