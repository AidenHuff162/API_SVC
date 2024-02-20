module Api
  module V1
    module Admin
      class HolidaysController < ApiController
        before_action :require_company!
        before_action :authenticate_user!

        load_and_authorize_resource
        authorize_resource only: [:holidays_index, :update, :destroy, :create]

        def holidays_index
          collection = HolidaysCollection.new(holiday_index_params)
          results = collection.results
          render json: {
              draw: params[:draw].to_i,
              recordsTotal: collection.count,
              recordsFiltered: collection.count,
              data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: HolidaySerializer::Basic)
            }
        end

        def create
          form = HolidayForm.new(collection_params)
          form.save!
          respond_with form.holiday, serializer: HolidaySerializer::Basic
        end

        def destroy
          @holiday.destroy!
          head 204
        end

        def show
          respond_with @holiday, serializer: HolidaySerializer::Basic
        end

        def update
          @holiday.update!(holiday_params)
          respond_with @holiday, serializer: HolidaySerializer::Basic
        end

        def user_holidays
          collection = HolidaysCollection.new(user_holidays_params)
          results = collection.results
          respond_with results, each_serializer: HolidaySerializer::Basic
        end
        private

        def collection_params
          params.merge(company_id: current_company.id, created_by_id: current_user.id)
        end

        def holiday_index_params
          page = (params[:start].to_i / params[:length].to_i) + 1
          sort_column = params["columns"][params["order"]["0"]["column"]]["data"]
          sort_order = params["order"]["0"]["dir"]
          params.merge(
            company_id: current_company.id,
            page: page,
            per_page: params[:length].to_i,
            order_column: sort_column,
            order_in: sort_order,
          )
        end

        def user_holidays_params
          params.merge(company_id: current_company.id)
        end

        def holiday_params
          params.permit(:name, :begin_date, :end_date, :multiple_dates, :status_permission_level => [], :team_permission_level => [], :location_permission_level => []).merge(created_by_id: current_user.id, company_id: current_company.id)
        end
      end
    end
  end
end
