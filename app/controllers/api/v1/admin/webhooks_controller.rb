module Api
  module V1
    module Admin
      class WebhooksController < BaseController
        skip_before_action :authenticate_user!, only: [:receive_test_event, :subscribe_zap, :unsubscribe_zap, :authenticate_zap, :perform_list_zap], raise: false
        skip_before_action :verify_current_user_in_current_company!, only: [:receive_test_event, :subscribe_zap, :unsubscribe_zap, :authenticate_zap, :perform_list_zap], raise: false
        load_and_authorize_resource only: [:update, :destroy, :test_event, :create, :show]
        authorize_resource only: [:paginated, :new_test_event]
        
        def receive_test_event
          puts "----------\n"*12
          puts params
          puts "----------\n"*12
          create_general_logging(current_company, 'Testing Webhook Event', params)
        end

        def paginated
          collection = WebhooksCollection.new(paginated_params)
          results = collection.results
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.count,
            recordsFiltered: collection.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: WebhooksSerializer::ForTable, company: current_company)
          }
        end

        def create
          @webhook.save!
          respond_with @webhook, serializer: WebhooksSerializer::Basic, company: current_company
        end

        def show
          respond_with @webhook, serializer: WebhooksSerializer::ForDialog, company: current_company
        end

        def update
          @webhook.update!(webhook_params)
          respond_with @webhook, serializer: WebhooksSerializer::Basic, company: current_company
        end

        def test_event
          WebhookEventServices::CreateTestEventService.new(current_company, @webhook, current_user).perform
        end

        def new_test_event
          webhook = WebhookEventServices::ExecuteTestEventService.new(test_params, current_company).perform
          respond_with webhook.to_json
        end

        def subscribe_zap
          status = WebhookServices::ZapierService.new(params, current_company).subscribe
          case status[:code]
          when 204
            respond_with status: status
          when 404
            render json: { errors: [Errors::NotFound.new("End-Point Not Found.").error] }, status: :not_found
          when 400
            render json: { errors: [Errors::BadRequest.new("Already Exists").error] }, status: :bad_request
          end 
        end

        def unsubscribe_zap
          status = WebhookServices::ZapierService.new(params,current_company).unsubscribe
          case status[:code]
          when 204
            respond_with status: status
          when 404
            render json: { errors: [Errors::NotFound.new("End-Point Not Found").error] }, status: :not_found 
          end 
        end

        def authenticate_zap
          if WebhookServices::ZapierService.new(params, current_company).authenticate
            respond_with status: 200
          else
            render json: { errors: [Errors::Unauthorized.error] }, status: :unauthorized
          end
        end

        def generate_zap_key 
          token = "#{SecureRandom.hex(15)}#{User.current.id}#{Time.now.to_i}"
          respond_with token: token
        end

        def perform_list_zap
          data = WebhookServices::ZapierService.new(params, current_company).perform_list_zap
          respond_with [data]
        end

        def destroy
          @webhook.destroy!
          head 204
        end

        private

        def webhook_params
          params.merge!(company_id: current_company.id, updated_by_id: current_user.id).permit(:state, :updated_by_id, :event, :target_url, :description, :webhook_key, :zapier, :created_by_id, :created_from, filters: {}, configurable: {})
        end

        def test_params
          id = "event_" + SecureRandom.hex
          params.permit(:event, :target_url).merge(event_id: id)
        end

        def paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1
          column_map = {"0": "event", "4": "triggered_at"}
          sort_column = column_map[params["order"]["0"]["column"].to_sym] rescue ""
          sort_order = params["order"]["0"]["dir"]

          if sort_column.nil?
            sort_column = "event"
          end
          params.merge(
            company_id: current_company.id,
            page: page,
            per_page: params[:length].to_i,
            order_column: sort_column,
            order_in: sort_order,
            term: params["search"]["value"].empty? ? nil : params["search"]["value"],
            current_user: current_user
          )
        end
      end
    end
  end
end