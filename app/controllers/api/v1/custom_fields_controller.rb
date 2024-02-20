module Api
  module V1
    class CustomFieldsController < ApiController
      include ADPHandler, IntegrationHandler
      include IntegrationFilter, WebhookHandler, CustomSectionApprovalHandler
      include HrisIntegrationsService::Workday::Logs

      before_action :require_company!
      before_action :authenticate_user!
      before_action :authorize_user , only: [:index, :preboarding_visible_field_index, :home_info_page_index, :custom_groups, :home_group_field, :mcq_custom_fields, :people_page_custom_groups, :report_custom_groups, :create_requested_fields_for_cs_approval]

      before_action only: [:people_page_custom_groups] do
        ::PermissionService.new.checkPeoplePageVisibility(current_user)
      end

      load_and_authorize_resource

      def index
        collection = CustomFieldsCollection.new(access_collection_params)
        indentification_edit = params[:indentification_edit] || false
        respond_with collection.results.includes(:sub_custom_fields, :custom_field_options), each_serializer: CustomFieldSerializer::WithValue, user_id: params[:user_id] || current_user.id, indentification_edit: indentification_edit, current_user: current_user, approval_profile_page: params[:approval_profile_page]
      end

      def preboarding_visible_field_index
        collection = CustomFieldsCollection.new(preboarding_visible_field_params)
        respond_with collection.results, each_serializer: CustomFieldSerializer::WithValue, user_id: params[:user_id] || current_user.id
      end

      def preboarding_page_index
        collection = CustomFieldsCollection.new(preboarding_page_collection_params)
        respond_with collection.results, each_serializer: CustomFieldSerializer::PreboardingPageWithValue, user_id: current_user.id
      end

      def home_info_page_index
        indentification_edit = params[:indentification_edit] || false
        collection = CustomFieldsCollection.new(home_info_page_collection_params)
        respond_with collection.results.includes(:sub_custom_fields, :custom_field_options), each_serializer: CustomFieldSerializer::HomeInfoPageWithValue,
        user_id: params[:user_id] || current_user.id, indentification_edit: indentification_edit, approval_profile_page: params[:approval_profile_page]
      end

      def home_job_details_page_index
        indentification_edit = params[:indentification_edit] || false
        collection = CustomFieldsCollection.new(home_job_details_page_collection_params)
        respond_with collection.results.includes(:sub_custom_fields, :custom_field_options), each_serializer: CustomFieldSerializer::HomeInfoPageWithValue,
        user_id: params[:user_id] || current_user.id, indentification_edit: indentification_edit, approval_profile_page: params[:approval_profile_page]
      end

      def custom_groups
        collection = CustomFieldsCollection.new(custom_group_params)
        respond_with collection.results, each_serializer: CustomFieldSerializer::CustomPeopleGroup
      end

      def report_custom_groups
        collection = CustomFieldsCollection.new(custom_group_params.merge({skip_employment_status: true}))
        respond_with collection.results, each_serializer: CustomFieldSerializer::ReportCustomPeopleGroup
      end

      def people_page_custom_groups
        collection = CustomFieldsCollection.new(custom_group_params)
        respond_with collection.results, each_serializer: CustomFieldSerializer::CustomPeopleGroup
      end

      def create_requested_fields_for_cs_approval
        fields = prepare_fields_for_cs_approval(params.to_h, params[:user_id], false, 'custom_field')
        if fields.present?
          render json: { status: 200, fields: fields}
        else
          render json: { status: 204 }
        end
      end

      def update
        field_name = nil
        custom_field_value = nil
        update_custom_field_params = custom_field_params
        tempUser = get_user(params[:user_id])
        if update_custom_field_params[:custom_field_values_attributes] && update_custom_field_params[:custom_field_values_attributes].first[:id]
          custom_field_value = current_company.users.find(update_custom_field_params[:custom_field_values_attributes].first[:user_id]).custom_field_values.find(update_custom_field_params[:custom_field_values_attributes].first[:id])
        end
        old_value = tempUser.get_custom_field_value_text(@custom_field.name, false, nil, @custom_field)

        begin
          field_name = get_field_name_needs_to_be_updated(update_custom_field_params, custom_field_value)
        rescue Exception => e
        end
        if update_custom_field_params[:custom_field_values_attributes]
          if tempUser.state == "active"
            if update_custom_field_params[:custom_field_values_attributes].first[:id]
              #:nocov:
              if @custom_field.section == "additional_fields" && update_custom_field_params[:custom_field_values_attributes].first[:value_text] != custom_field_value.value_text
                PushEventJob.perform_later('additional-fields-updated', current_user, {
                  employee_name: tempUser[:first_name] + ' ' + tempUser[:last_name],
                  employee_email: tempUser[:email],
                  field_name: @custom_field.name,
                  value_text: update_custom_field_params[:custom_field_values_attributes].first[:value_text],
                  company: current_company[:name]
                })
              end
              #:nocov:
            end
          end
          begin
            if custom_field_value.present? && ( update_custom_field_params[:custom_field_values_attributes].first[:value_text] != custom_field_value.value_text || update_custom_field_params[:custom_field_values_attributes].first[:custom_field_option_id] != custom_field_value.custom_field_option_id )
              SlackNotificationJob.perform_later(current_company.id, {
                username: tempUser.full_name,
                text: I18n.t('slack_notifications.custom_field.updated', field_name: @custom_field.name, first_name: tempUser[:first_name], last_name: tempUser[:last_name])
              })
            end

          rescue Exception => e
            p e
          end
        end
        if current_user.id == tempUser.id
          description = I18n.t('history_notifications.custom_field.self_updated', user_first_name: tempUser.first_name, user_last_name: tempUser.last_name , field_name: @custom_field.name)
        else
          description = I18n.t('history_notifications.custom_field.updated',user_first_name: current_user.first_name, user_last_name: current_user.last_name, field_name: @custom_field.name, employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name)
        end
        if field_name
          CreateHistoryLogJob.perform_later(current_user.id,description,tempUser.id,field_name)
        else
          CreateHistoryLogJob.perform_later(current_user.id,description,tempUser.id,update_custom_field_params[:name]) if update_custom_field_params[:name].present?
        end


        if update_custom_field_params["custom_field_values_attributes"] && !update_custom_field_params["custom_field_values_attributes"][0]["checkbox_values"].present?
          if custom_field_value
            #:nocov:
            custom_field_value.checkbox_values = []
            custom_field_value.save!
            #:nocov:
          end
        end
        @custom_field.update!(update_custom_field_params)
        tempUser.update_column(:fields_last_modified_at, Date.today)
        respond_with @custom_field, serializer: CustomFieldSerializer::WithValue, user_id: tempUser.id
        #:nocov:
        begin
          send_updates_to_integrations(tempUser, field_name) if field_name.present?
          new_value = tempUser.get_custom_field_value_text(@custom_field.name)
          send_updates_to_webhooks(current_company, {event_type: 'custom_field', custom_field_id: @custom_field.id, old_value: old_value, new_value: new_value, user_id: tempUser.id })
        rescue Exception => e
        end
        #:nocov:
      end

      def get_field_name_needs_to_be_updated(update_custom_field_params, custom_field_value)
        if update_custom_field_params[:custom_field_values_attributes].present?

          value_text = update_custom_field_params[:custom_field_values_attributes].first[:value_text] rescue nil
          custom_field_option_id = update_custom_field_params[:custom_field_values_attributes].first[:custom_field_option_id] rescue nil

          if (custom_field_value.present? && ( value_text != custom_field_value.value_text || custom_field_option_id != custom_field_value.custom_field_option_id )) || (custom_field_value.blank? && (value_text.present? || custom_field_option_id.present?))
            return @custom_field.name
          end
        end

        if update_custom_field_params[:sub_custom_fields_attributes].present?
          update_custom_field_params[:sub_custom_fields_attributes].each do |key, value|
            if value[:custom_field_values_attributes].present?

              value_text = value[:custom_field_values_attributes].first[:value_text] rescue nil
              custom_field_option_id = value[:custom_field_values_attributes].first[:custom_field_option_id] rescue nil
              sub_custom_field_value = CustomFieldValue.find_by_id(value[:custom_field_values_attributes].first[:id]) if value[:custom_field_values_attributes].first[:id]

              if (sub_custom_field_value.present? && ( value_text != sub_custom_field_value.value_text || custom_field_option_id != sub_custom_field_value.custom_field_option_id )) || (sub_custom_field_value.blank? && (value_text.present? || custom_field_option_id.present? ))
                return @custom_field.name
              end
            end
          end
        end

        return nil
      end
      def send_updates_to_integrations(user, field_name)
        user.reload
        if user.present?
          if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| current_company.integration_types.include?(api_name) }.present?
            update_adp_profile(user.id, @custom_field.name, @custom_field.id) if (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
          end

          ::HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.perform_later(user, @custom_field.name) if user.bamboo_id.present?

          if current_company.can_provision_adfs? && user.active_directory_object_id.present?
            manage_adfs_productivity_update(user, [@custom_field.name], true)
          end

          if current_company.authentication_type == 'one_login' && user.one_login_id.present?
            manage_one_login_updates(user, @custom_field.name, true)
          end

          Okta::UpdateEmployeeInOktaJob.perform_async(user.id) if user.okta_id.present? && Integration.okta_custom_fields(user.company_id).include?(@custom_field.name)

          ::IntegrationsService::UserIntegrationOperationsService.new(user, ['deputy', 'peakon', 'trinet', 'gusto', 'lattice', 'paychex', 'kallidus_learn', 'paylocity', 'namely', 'xero', 'workday'], [], { is_custom: true, name: @custom_field.name.downcase } ).perform('update')
      
          manage_gsuite_update(user, current_company, {google_groups: true}) if current_company.google_groups_feature_flag.present? && field_name == "Google Organization Unit"
        end
      end

      def home_group_field
        custom_params = collection_params.merge(name: current_company.group_for_home)
        field = CustomFieldsCollection.new(custom_params).results

        if field && field.first
          respond_with field.first, serializer: CustomFieldSerializer::CustomHomeGroup, user_id: params[:user_id]
        else
          respond_with status: 404
        end
      end

      def mcq_custom_fields
        if params[:inbox]
          collection = current_company.custom_fields.where(field_type: [13])
        else
          collection = current_company.custom_fields.where(field_type: [4, 13])
        end

        respond_with collection, each_serializer: CustomFieldSerializer::WithOptionsBasic
      end

      def bulk_update_custom_fields_to_integrations
        user, updated_fields = get_user(params[:user_id]), params[:custom_field_names]
        return if updated_fields.blank?

        if user.workday_id.present?
          HrisIntegrations::Workday::UpdateWorkdayUserFromSaplingJob.perform_later(user.id, updated_fields)
          respond_with status: 200
          log_to_wd_teams_channel(user, "UpdatedFields: [#{updated_fields.join(', ')}]", 'Workday Bulk Update Logs - Prod')
        end
      end

      private

      def custom_group_params
        params.merge(company_id: current_company.id, integration_group: true)
      end

      def access_collection_params
        params.merge({ company_id: current_company.id, current_user_id: current_user.id, current_user_role: current_user.user_role, check_access: true })
      end

      def collection_params
        params.merge(company_id: current_company.id)
      end

      def preboarding_visible_field_params
        user = current_company.users.find_by(id: params[:user_id] || current_user.id)
        params.merge(company_id: current_company.id)
      end

      def preboarding_page_collection_params
        params.merge!(company_id: current_company.id, is_preboarding_page: true)
      end

      def home_info_page_collection_params
        params.merge(company_id: current_company.id, sections: PermissionService.new.fetch_accessable_custom_field_sections(current_company, current_user, params[:user_id]), is_info_page: true, active_only: true)
      end

      def home_job_details_page_collection_params
        params.merge(company_id: current_company.id, coworker: true, active_only: true)
      end

      def custom_field_params
        user_id = params[:user_id] || current_user.id

        params.merge!(custom_field_values_attributes: [
          (params[:custom_field_value] || {}).merge(user_id: user_id)
        ])

        if params[:sub_custom_fields].present?
          params[:sub_custom_fields].each do |sub_custom_field|
            sub_custom_field.merge!(custom_field_values_attributes: [
              (sub_custom_field[:custom_field_value] || {}).merge(user_id: user_id)
            ])
          end
          sub_custom_fields = params[:sub_custom_fields]
          sub_custom_fields_hash = Hash[*sub_custom_fields.each_with_index.map {|val, i| [i.to_s, val]}.flatten]
          params.merge!(sub_custom_fields_attributes:
            (sub_custom_fields_hash || {})
          )
        end

        if params[:custom_field_options].present?
          custom_field_options = params[:custom_field_options]
          custom_field_options_hash = Hash[*custom_field_options.each_with_index.map {|val, i| [i.to_s, val]}.flatten]
          params.merge!(custom_field_options_attributes:
            (custom_field_options_hash || {})
          )
        end

        if CustomField.typehHasSubFields(params[:field_type])
          params.permit(:id, :section, :position, :name, :help_text, :default_value, :field_type, :required, :required_existing, :collect_from_manager, :collect_from, :skip_validations,
          sub_custom_fields_attributes: [:id, :name, :field_type, :help_text, custom_field_values_attributes:
            [:id, :value_text, :user_id, :custom_field_option_id, checkbox_values: []]]).merge(company_id: current_company.id)
        else
          params.permit(:id, :section, :position, :name, :help_text, :default_value, :field_type, :required, :required_existing, :collect_from_manager, :collect_from, :skip_validations,
          custom_field_values_attributes: [:id, :value_text, :user_id, :custom_field_option_id, :sub_custom_field_id, :coworker_id, checkbox_values: []],
          custom_field_options_attributes: [:id, :option, :position, :description]).merge(company_id: current_company.id)
        end
      end

      def get_user(id)
        current_company.users.find_by(id: (id || current_user.id))
      end

    end
  end
end
