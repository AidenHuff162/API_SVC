module Api
  module V1
    module Admin
      module WebhookIntegrations
        class WorkdayController < WebhookController

          def manage_sapling_users
            event_objects = notification_params_hash[:event_objects]
            case event_objects
            when Array
              event_objects.each { |event_object| handle_event_object(event_object) }
            when Hash
              handle_event_object(event_objects)
            end
          end

        private

          def notification_params_hash
            event_data = params[:notification_data][:event_data]
            {
              event_id: event_data[:event_reference][:id][0],
              event_name: event_data[:event_name],
              notification_trigger: event_data[:notification_trigger],
              event_completion_date: event_data[:event_completion_date],
              tenant_name: event_data[:tenant_name],
              system_id: event_data[:system_id],
              event_objects: event_data[:transaction_target_reference]
            }
          end

          def handle_event_object(event_object)
            event_object_type = event_object[:id][:'@wd:type']
            if %w[Employee_ID Contingent_Worker_ID].include?(event_object_type.to_s)
              event_object_id = event_object[:id][0] #to get wid of the object
              HrisIntegrationsService::Workday::ManageWorkdayInSapling.new(current_company.id, event_object_type, event_object_id).perform('fetch_notified')
            end
          end

        end
      end
    end
  end
end