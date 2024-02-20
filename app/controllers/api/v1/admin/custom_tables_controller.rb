module Api
  module V1
    module Admin
      class CustomTablesController < BaseController
        load_and_authorize_resource except: [:index, :home_index, :reporting_index, :permission_page_index, :group_page_index, :bulk_onboarding_index]
        authorize_resource only: [:index, :webhook_page_index, :home_index, :reporting_index, :permission_page_index, :group_page_index, :bulk_onboarding_index]

        def index
          collection = CustomTablesCollection.new(collection_params)
          respond_with collection.results, each_serializer: CustomTableSerializer::Basic
        end

        def webhook_page_index
          collection = CustomTablesCollection.new(collection_params)
          respond_with collection.results, each_serializer: CustomTableSerializer::CustomTableForWebhooks
        end

        def home_index
          collection = CustomTablesCollection.new(home_index_page_collection_params)
          respond_with collection.results, each_serializer: CustomTableSerializer::CustomTableForInfo, user_id: params[:user_id], include: '**'
        end

        def reporting_index
          collection = CustomTablesCollection.new(collection_params.merge(custom_table_ids: PermissionService.new.fetch_reports_accessible_custom_tables(current_user, current_company), is_reporting_page: true))
          respond_with collection.results, each_serializer: CustomTableSerializer::CustomTableForReports
        end

        def permission_page_index
          collection = CustomTablesCollection.new(collection_params)
          respond_with collection.results, each_serializer: CustomTableSerializer::Base
        end

        def group_page_index
          collection = CustomTablesCollection.new(collection_params)
          respond_with collection.results, each_serializer: CustomTableSerializer::CustomTableForGroups
        end

        def bulk_onboarding_index
          collection = CustomTablesCollection.new(collection_params)
          respond_with collection.results, each_serializer: CustomTableSerializer::BulkOnboarding
        end

        def create
          @custom_table.save!
          @custom_table.add_custom_table_to_profile_template(current_company, params[:profile_template_ids]) if params[:profile_template_ids].present?
          respond_with @custom_table, serializer: CustomTableSerializer::Basic
        end

        def update
          @custom_table.update!(update_custom_table_params)
          respond_with @custom_table, serializer: CustomTableSerializer::Basic
        end

        def destroy
          ProfileTemplateCustomTableConnection.where(custom_table_id: @custom_table.id).with_deleted.delete_all
          ProfileTemplateCustomFieldConnection.where(custom_field_id: @custom_table.custom_fields.pluck(:id)).with_deleted.delete_all
          @custom_table.destroy
          head 204
        end

        def custom_tables_bulk_operation
          collection = CustomTablesCollection.new(collection_params)
          respond_with collection.results, each_serializer: CustomTableSerializer::MinimalData
        end

        def custom_table_columns
          respond_with CustomTables::FetchCustomTableColumns.new(current_company, @custom_table).perform
        end

        private

        def custom_table_params
          updateParamsApprovalIds() if params[:position_changed].blank?
          params[:custom_fields].each {|h| h[:company_id]=current_company.id} if params[:custom_fields].present?
          params.merge!(approval_chains_attributes: params[:approval_chains], company_id: current_company.id, custom_fields_attributes: params[:custom_fields]).permit(:id, :name, :table_type, :position, :approval_type, :is_approval_required, :approval_expiry_time, approval_ids: [], approval_chains_attributes: [:id, :approval_type, :_destroy, approval_ids: []], custom_fields_attributes: [:name, :field_type, :collect_from, :company_id])
        end

        def update_custom_table_params
          updateParamsApprovalIds() if params[:position_changed].blank?
          params.merge!(approval_chains_attributes: params[:approval_chains], company_id: current_company.id).permit(:id, :name, :table_type, :position, :approval_type, :is_approval_required, :approval_expiry_time, approval_ids: [], approval_chains_attributes: [:id, :approval_type, :_destroy, approval_ids: []])
 
        end

        def updateParamsApprovalIds
          params[:approval_ids] ||= []
          params[:approval_ids].delete('')
        end

        def collection_params
          params.merge(company_id: current_company.id, enable_custom_table_approval_engine: current_company.enable_custom_table_approval_engine)
        end

        def home_index_page_collection_params
          params.merge(company_id: current_company.id, custom_table_ids: PermissionService.new.fetch_accessable_custom_tables(current_company, current_user, params[:user_id]), is_home_page: true, enable_custom_table_approval_engine: current_company.enable_custom_table_approval_engine)
        end
      end
    end
  end
end
