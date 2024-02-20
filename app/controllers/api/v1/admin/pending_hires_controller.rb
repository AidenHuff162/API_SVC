module Api
  module V1
    module Admin
      class PendingHiresController < BaseController

        before_action :set_pending_hire, only: [:update, :show, :destroy]
        before_action only: [:paginated_hires, :bulk_update, :create_bulk_users] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
        end

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def index
          if params[:user_id]
            respond_with current_company.pending_hires.where(state: 'active', id: params[:user_id]), each_serializer: PendingHireSerializer::Full
          else
            respond_with current_company.pending_hires.where(state: 'active'), each_serializer: PendingHireSerializer::Full
          end
        end

        def show
          respond_with @pending_hire, serializer: PendingHireSerializer::Full, scope: { duplication: params[:duplication] }, include: '**'
        end

        def create
          pending_hire = pending_hire_params[:personal_email].nil? ? nil : current_company.pending_hires.find_by(personal_email: pending_hire_params[:personal_email]) 
          if !pending_hire.present?
            pending_hire = PendingHire.create(pending_hire_params) 
          elsif !pending_hire.user_id
            pending_hire = pending_hire.update!(pending_hire_params) 
          end
          render json: {pending_hire: pending_hire}, status: 200
        end

        def update
          user = @pending_hire.user if params[:duplicate_option] == 'new' && @pending_hire
          status = @pending_hire.update!(pending_hire_params) if @pending_hire

          if status && user
            new_email = @pending_hire.personal_email.gsub(/@/, '+old@')
            user.personal_email  == @pending_hire.personal_email ? user.update(personal_email: new_email) : user.update(email: new_email)
          end

          head 204
        end

        def paginated_hires
          collection = PendingHiresCollection.new pending_hires_paginated_params
          results = collection.results.includes(:user)
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.count,
            recordsFiltered: collection.count,
            duplication_count: collection.duplication_count_filter,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: PendingHireSerializer::Light)
          }
        end

        def destroy
          @pending_hire.delete_hire
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def bulk_delete
          if params[:pending_hires].present? && current_company.present?
            current_company.pending_hires.where(id: params[:pending_hires]).each do |pending_hire|
              pending_hire.delete_hire
            end
          end
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def download_csv
          csv_data = PendingHireServices::GetCsvData.new.perform(params[:pending_hires], current_company) if params[:pending_hires].present? && current_company.present?
          render json: {csv_data: csv_data}, status: 200
        end

        def pending_hires_count
          render json: {count: current_company.pending_hires.where(state: 'active').count}, status: 200
        end

        def set_pending_hire
          if params[:id]
            @pending_hire = current_company.pending_hires.find(params[:id])
          else
            @pending_hire = current_company.pending_hires.find_by_user_id(params[:user_id])
          end
        end

        def bulk_update
          updated = false
          if bulk_update_params[:pending_hires].present? && current_company.present?
            hires = current_company.pending_hires.where(id: bulk_update_params[:pending_hires])
            hires.update_all(location_id:bulk_update_params[:location_id] ,
              team_id: bulk_update_params[:team_id], employee_type: bulk_update_params[:employee_type])
            if params[:custom_groups]
              hires.each do |user|
                params[:custom_groups].each do |custom_field_id, option_id|
                  user.set_custom_group_field_option(custom_field_id, option_id.first)
                end
              end
            end
            updated = true
          end

          render json: {updated: updated}, status: 200
        end

        def create_bulk_users
          
          if params['pending_hires'].present?
            hires = current_company.pending_hires.where(id: params['pending_hires'])
            hires.each do |hire|
              hire.create_user if hire.user_id.blank?
            end
          end

          respond_with current_company.pending_hires.where(state: 'active', id: params['pending_hires']), each_serializer: PendingHireSerializer::Full
        end

        private
        def collection_params
          params.merge(company_id: current_company.id, user_id: params[:user_id])
        end

        def pending_hire_params
          params.permit(:user_id, :first_name, :personal_email, :last_name, :team_id, :location_id, :working_pattern_id, :manager_id, :start_date, :title, :employee_type, :provision_gsuite, :send_credentials_type, :send_credentials_offset_before, :send_credentials_time, :send_credentials_timezone, :duplication_type, :skipping_duplication).merge!(company_id: current_company.id)
        end

        def pending_hires_paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1
          column_map = { '1': 'name', '2': 'start_date', '3': 'title', '4': 'manager_name', '5': 'location_name',
                         '6': 'team_name', '7': 'employee_type' }
          sort_column = column_map[params["order"]["0"]["column"].to_sym] rescue ""
          sort_order = params["order"]["0"]["dir"]

          params.merge(
            company_id: current_company.id,
            page: page,
            per_page: params[:length].to_i,
            order_column: sort_column,
            order_in: sort_order,
            term: params["search"]["value"].empty? ? nil : params["search"]["value"]
          )
        end

        def bulk_update_params
          params.permit(:team_id, :location_id, :employee_type, pending_hires: [])
        end
      end
    end
  end
end
