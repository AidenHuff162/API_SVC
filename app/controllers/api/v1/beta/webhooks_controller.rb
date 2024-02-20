module Api
  module V1
    module Beta
      class WebhooksController < BaseController

        def index
          data = @sapling_api.manage_webhooks_routes('index', params)
          respond_with data, status: data[:status]
        end

        def show
          data = @sapling_api.manage_webhooks_routes('show', params)
          respond_with data, status: data[:status]
        end

        def create
          data = @sapling_api.manage_webhooks_routes('create', params)
          respond_with data, status: data[:status]
        end

        def update
          data = @sapling_api.manage_webhooks_routes('update', params)
          respond_with data, status: data[:status]
        end

        def destroy
          data = @sapling_api.manage_webhooks_routes('destroy', params)
          render body: data.to_json, status: data[:status]
        end
      end
    end
  end
end