module Api
  module V1
    module Admin
      class CustomEmailAlertsController < BaseController
        load_and_authorize_resource except: [:index, :paginated, :duplicate_alert]
        authorize_resource only: [:index, :paginated, :duplicate_alert]

        def index
          if current_company.enabled_time_off
            respond_with current_company.custom_email_alerts, each_serializer: CustomEmailAlertSerializer::ForTable, company: current_company
          else
            respond_with current_company.custom_email_alerts.where(alert_type: [4, 5, 7]), each_serializer: CustomEmailAlertSerializer::ForTable, company: current_company
          end
        end

        def paginated
          collection = CustomEmailAlertsCollection.new(paginated_params)

          results = collection.results

          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.count,
            recordsFiltered: collection.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: CustomEmailAlertSerializer::ForTable, company: current_company)
          }
        end

        def show
          respond_with @custom_email_alert, serializer: CustomEmailAlertSerializer::ForDialog
        end

        def create
          @custom_email_alert.save!
          respond_with @custom_email_alert, serializer: CustomEmailAlertSerializer::ForTable, company: current_company
        end

        def update
          @custom_email_alert.update!(custom_email_alert_params)
          respond_with @custom_email_alert, serializer: CustomEmailAlertSerializer::ForTable, company: current_company
        end

        def destroy
          @custom_email_alert.destroy!
          render body: Sapling::Application::EMPTY_BODY, status: 201
        end

        def send_test_alert
          CustomEmailAlert.sent_custom_alert_test_email(CustomEmailAlert.new(custom_email_alert_params.to_h), current_user)
        end

        def duplicate_alert
          alert = current_company.custom_email_alerts.find_by(id: params[:id])
          new_alert = alert.dup
          pattern = "%#{new_alert.title.to_s[0,new_alert.title.length]}%"
          title = alert.title.insert(0, 'Copy of ')
          title = title.insert(title.length, " (#{current_company.custom_email_alerts.where("title LIKE ? ",pattern).count+1})")
          new_alert.title = title
          new_alert.save!
          respond_with new_alert, serializer: CustomEmailAlertSerializer::ForTable, company: current_company
        end

        private

        def custom_email_alert_params
          params.merge!(company_id: current_company.id, edited_by_id: current_user.id).permit(:title, :subject, :body, :alert_type, :notified_to, :company_id, :edited_by_id, :is_enabled, :enabled_time_off, :applied_to_teams => [], :applied_to_locations => [],
            :applied_to_statuses => [], :notifiers => [])
        end

        def paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1
          column_map = {"0": "title", "1": "applies_to"}
          sort_column = column_map[params["order"]["0"]["column"].to_sym] rescue ""
          sort_order = params["order"]["0"]["dir"]

          if sort_column.nil?
            sort_column = "title"
          end
          params.merge(
            enabled_time_off: current_company.enabled_time_off,
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
