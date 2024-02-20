module Api
  module V1
    module Admin
      class FieldHistoriesController < BaseController
        before_action :authenticate_user!
        before_action :set_field_holder, only: :index
        before_action :set_field_history_entry, only: [:update, :destroy, :show_identification_numbers]
        before_action :all_historic_entries_for_a_field, only: :index
        before_action only: :index do
          ::PermissionService.new.check_user_visibility(current_user, current_company, params)
        end

        load_and_authorize_resource

        def index
          respond_with @field_histories, each_serializer: FieldHistorySerializer::Index, scope: {company: current_company}
        end

        def update
          @field_history.update(field_history_params)
          respond_with @field_history, serializer: FieldHistorySerializer::Index, scope: {company: current_company}
        end

        def destroy
          @field_history.destroy
          head 204
        end

        def show_identification_numbers
          identification_edit = params[:identification_edit] || false
          respond_with @field_history, serializer: FieldHistorySerializer::Index, identification_edit: identification_edit, scope: {company: current_company}
        end

        private

        def field_history_params
          params.permit(:new_value).merge(field_changer_id: current_user.id)
        end

        def set_field_history_entry
          field_auditable_type = [User, Profile].find { |x| x.name == params[:field_auditable_type] }
          field = field_auditable_type ? field_auditable_type.find_by(id: params[:field_auditable_id]) : nil
          @field_history = field ? field.field_histories.find_by(id: params[:id]) : nil
        end

        def set_field_holder
          user_id =  params[:resource_type] == 'CustomField' ? params[:resource_id].to_i : params[:user_id].to_i
          @field_holder = current_company.users.find_by_id(user_id)
        end


        def all_historic_entries_for_a_field
          if params[:resource_type] == 'CustomField'
            @field_histories = @field_holder.field_histories.by_custom_field_name params[:field_name]
          else
            attribute = params[:resource_type] == 'User' ? @field_holder : @field_holder.profile rescue nil
            if attribute.present?
              @field_histories = attribute.field_histories.by_field_name(@field_holder.get_actual_field_name(params[:field_name]))
            else
              @field_histories = []
            end
          end
        end
      end
    end
  end
end
