module Api
  module V1
    module Admin
      class WebhookEventsController < BaseController
        load_and_authorize_resource only: [:show, :redeliver]
        authorize_resource only: :index

        def index
          collection = WebhookEventsCollection.new(collection_params)
          respond_with collection.results, each_serializer: WebhookEventsSerializer::Simple, company: current_company, meta: {count: collection.count}, adapter: :json
        end

        def show
          respond_with @webhook_event, serializer: WebhookEventsSerializer::Basic, company: current_company
        end

        def redeliver
          WebhookEvents::ExecuteWebhookEventJob.new.perform(current_company.id, @webhook_event.id)
          respond_with @webhook_event.reload, serializer: WebhookEventsSerializer::Basic, company: current_company
        end

        private

        def collection_params
          params.merge(company_id: current_company.id)
        end

      end
    end
  end
end