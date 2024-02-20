module Api
  module V1
    module Admin
      module WebhookIntegrations
        class GreenhouseController < WebhookController

          def create
            if current_company.present?
              webhook_executed = 'failed'
              message = nil
              error = nil
              
              begin
                hired_candidate = params.to_h[:greenhouse][:payload][:application] rescue nil
                if hired_candidate.present?
                  PendingHire.create_by_greenhouse(hired_candidate, current_company) if hired_candidate['candidate'].present?
                end
                current_company.update(is_recruitment_system_integrated: true) unless current_company.is_recruitment_system_integrated?
                greenhouse_integration = current_company.integration_instances.find_by(api_identifier: 'green_house')
                greenhouse_integration.update_column(:synced_at, DateTime.now) if greenhouse_integration
                webhook_executed = 'succeed'

                log_success_webhook_statistics(current_company)
              rescue Exception => exception
                error = exception.message
                webhook_executed = 'failed'
                message = "The #{current_company.name} has failed to pull data for Greenhouse. We received error as #{exception.inspect} with params #{params.to_json}"
                log_failed_webhook_statistics(current_company)
              ensure
                params.merge!(hired_candidate: hired_candidate.try(:to_hash))
                create_webhook_logging(current_company, 'Greenhouse', 'Created by Api', params.to_json, webhook_executed, 'GreenhouseController/create', error)
                
                ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
                    IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:applicant_tracking_system])) if message.present?
              end
            end

            return render json: true
          end

          def mail_parser
            if current_company.present?
              webhook_executed = 'failed'
              message = nil
              error = nil
              
              begin
                hired_candidate = params["greenhouse"] rescue nil
                if hired_candidate.present?
                  PendingHire.create_by_greenhouse_mail_parser(hired_candidate, current_company)
                end
                current_company.update(is_recruitment_system_integrated: true) unless current_company.is_recruitment_system_integrated?
                webhook_executed = 'succeed'

                log_success_webhook_statistics(current_company)
              rescue Exception=>exception
                error = exception.message
                webhook_executed = 'failed'
                message = "The #{current_company.name} has failed to parse data for Greenhouse. We received #{params.to_json}"

                log_failed_webhook_statistics(current_company)
              ensure
                params.merge!(hired_candidate: hired_candidate.try(:to_hash))

                create_webhook_logging(current_company, 'Greenhouse', 'Created by Mail Parser', params.to_json, webhook_executed, 'GreenhouseController/mail_parser', error)

                ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
                    IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:applicant_tracking_system])) if message.present?
              end
            end

            return render json: true
          end
        end
      end
    end
  end
end
