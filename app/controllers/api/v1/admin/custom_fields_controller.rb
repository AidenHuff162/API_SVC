module Api
  module V1
    module Admin
      class CustomFieldsController < BaseController
        include ADPHandler, IntegrationHandler
        include IntegrationFilter, WebhookHandler, CustomSectionApprovalHandler
        skip_before_action :require_company!, only: [:custom_groups_org_chart], raise: false
        skip_before_action :authenticate_user!, only: [:custom_groups_org_chart], raise: false
        skip_before_action :verify_current_user_in_current_company!, only: [:custom_groups_org_chart], raise: false

        before_action :authorize_user, only: [:index, :onboarding_page_index, :request_info_index, :reporting_page_index, :employment_status_fields, :custom_groups, :export_employee_record, :create,:update_custom_group, :update, :create_requested_fields_for_cs_approval, :destroy, :delete_sub_custom_fields]
        load_and_authorize_resource except: [:index, :reporting_page_index, :employment_status_fields, :update_custom_group, :onboarding_page_index, :onboarding_info_fields, :request_info_index, :custom_groups_org_chart]
        authorize_resource only: [:index, :reporting_page_index, :employment_status_fields, :onboarding_page_index, :onboarding_info_fields, :request_info_index]

        before_action only: [:custom_groups, :reporting_page_index, :employment_status_fields, :index, :onboarding_page_index, :update_user_custom_group, :onboarding_info_fields , :offboarding_page_index] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab], action_name)
        end
        before_action only: [:onboarding_page_index, :onboarding_info_fields, :offboarding_page_index] do
          ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, params[:sub_tab], action_name)
        end

        before_action only: [:update, :create_requested_fields_for_cs_approval] do
          ::PermissionService.new.can_access_manager_form(current_user, params[:user_id]) if params[:user_id] && params[:user_id] != current_user.id && current_user.role == 'manager'
        end

        rescue_from CanCan::AccessDenied do |exception|
          if params[:sub_tab].present?
            render body: Sapling::Application::EMPTY_BODY, status: 204
          else
            head 403
          end
        end

        def index
          collection = CustomFieldsCollection.new(collection_params)
          respond_with collection.results.includes(:sub_custom_fields, :custom_field_options), each_serializer: CustomFieldSerializer::WithValue, user_id: params[:user_id]
        end

        def onboarding_page_index
          col = CustomFieldsCollection.new(collection_params.merge!(is_onboarding_page: true))
          collection = ActiveModelSerializers::SerializableResource.new(col.results, each_serializer: CustomFieldSerializer::OnboardingPageWithValue, user_id: params[:user_id]).serializable_hash
          result = ::CustomFields::OnboardSectionManagement.new(collection, current_company).perform
          respond_with result
        end

        def request_info_index
          collection = CustomFieldsCollection.new(collection_params.merge!(is_profile_fields: true))
          respond_with collection.results, each_serializer: CustomFieldSerializer::RequestInfo
        end

        def onboarding_info_fields
          collection = CustomFieldsCollection.new(collection_params.merge!(is_create_profile: true, is_using_custom_table: current_company.try(:is_using_custom_table)))
          respond_with collection.results.includes(:sub_custom_fields, :custom_field_options), each_serializer: CustomFieldSerializer::OnboardingPageWithValue, user_id: params[:user_id]
        end

        def offboarding_page_index
          collection = CustomFieldsCollection.new(collection_params.merge!(is_offboarding_page: true))
          respond_with collection.results.includes(:sub_custom_fields, :custom_field_options), each_serializer: CustomFieldSerializer::WithValue, user_id: params[:user_id]
        end

        def reporting_page_index
          collection = CustomFieldsCollection.new(collection_params.merge!(is_reporting_page: true))
          respond_with collection.results.includes(:sub_custom_fields, :custom_field_options), each_serializer: CustomFieldSerializer::ReportIndex, user_id: params[:user_id]
        end

        def employment_status_fields
          collection = CustomFieldsCollection.new(collection_params)
          respond_with collection.results.includes(:sub_custom_fields, :custom_field_options), each_serializer: CustomFieldSerializer::WithValue, user_id: params[:user_id]
        end

        def custom_groups
          custom_params = custom_groups_params
          collection = CustomFieldsCollection.new(custom_params)
          respond_with collection.results.includes(:custom_field_options , custom_field_options: [:custom_field_values, :owner]), each_serializer: CustomFieldSerializer::CustomGroup
        end

        def sa_configuration_custom_groups
          custom_params = custom_groups_params.merge(sa_configuration_filters: true)
          collection = CustomFieldsCollection.new(custom_params)
          respond_with collection.results.includes(:custom_field_options , custom_field_options: [:custom_field_values, :owner]), each_serializer: CustomFieldSerializer::CustomGroup
        end

        def sa_configuration_onboarding_custom_groups
          custom_params = custom_groups_params.merge(sa_configuration_onboarding_filters: true)
          collection = CustomFieldsCollection.new(custom_params)
          respond_with collection.results.includes(:custom_field_options , custom_field_options: [:custom_field_values, :owner]), each_serializer: CustomFieldSerializer::OnboardingPageWithValue, user_id: params[:user_id]
        end

        def paginated_custom_groups
          collection = CustomFieldsCollection.new(paginated_params)
          results = collection.results
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.nil? ? 0 : results.count,
            recordsFiltered: collection.nil? ? 0 : results.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: CustomFieldOptionSerializer::CustomGroup)
          }
        end

        def custom_groups_org_chart
          custom_params = custom_groups_params
          collection = CustomFieldsCollection.new(custom_params)
          respond_with collection.results.includes(:custom_field_options , custom_field_options: [:custom_field_values, :owner]), each_serializer: CustomFieldSerializer::CustomGroup
        end

        def export_employee_record
          if current_user.id.to_s == params[:user_id] || current_user.user_role.try(:role_type) == "super_admin"
            user = current_company.users.find_by_id(params[:user_id])
            respond_with user,
                       serializer: UserSerializer::EmployeeRecordCsv
          else
            render body: Sapling::Application::EMPTY_BODY, status: 204
          end
        end


        def create

          @custom_field.save!
          respond_with @custom_field, serializer: CustomFieldSerializer::WithValue
          PushEventJob.perform_later('custom-field-created', current_user, {
            field_name: custom_field_params[:name],
            field_section: custom_field_params[:section]
          })

          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t("slack_notifications.custom_field.created", field_name: custom_field_params[:name])
          })

          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t("history_notifications.custom_field.created", field_name: custom_field_params[:name])
          })
        end

        def update_custom_group
          custom_field_group = CustomFieldForm.new collection_params
          custom_field_group.save!
          respond_with custom_field_group&.record || custom_field_group, serializer: CustomFieldSerializer::CustomGroup
        end

        def update_user_custom_group
          respond_with CustomFieldValue.set_custom_field_value(current_company.users.find_by(id: params[:user_id]), @custom_field.name, params[:option])
        end

        def create_requested_fields_for_cs_approval
          fields = prepare_fields_for_cs_approval(params.to_h, params[:user_id], false, 'custom_field')
          if fields.present?
            render json: { status: 200 , fields: fields}
          else
            render json: { status: 204 }
          end
        end

        def update
          tempField = CustomFieldsCollection.new(id: custom_field_params[:id]).results.first
          field_name = nil
          begin
            field_name = get_field_name_needs_to_be_updated()
          rescue Exception => e

          end
          tempFieldValue = nil
          tempUser = nil
          slack_message = nil
          history_description = nil
          history_user = nil
          if custom_field_params[:custom_field_values_attributes].present?
            if custom_field_params[:custom_field_values_attributes].first[:id]
              user = current_company.users.find_by(id: custom_field_params[:custom_field_values_attributes].first[:user_id])
              if user
                tempFieldValue = user.custom_field_values.find_by(id: custom_field_params[:custom_field_values_attributes].first[:id])
              end
            end
            if custom_field_params[:custom_field_values_attributes].first[:user_id]
               tempUser = current_company.users.find_by(id: custom_field_params[:custom_field_values_attributes].first[:user_id])
            end
          end
          tempUser = current_company.users.find_by(id: params[:user_id]) unless tempUser.present? && !params[:user_id]

          old_value = tempUser.get_custom_field_value_text(@custom_field.name, false, nil, @custom_field) if tempUser.present?
          @custom_field.update!(custom_field_params)
          respond_with @custom_field, serializer: CustomFieldSerializer::WithValue, user_id: params[:user_id]
          
          if custom_field_params[:custom_field_values_attributes].present?
            if custom_field_params[:custom_field_values_attributes].first[:id]
              if @custom_field.section == "additional_fields" && custom_field_params[:custom_field_values_attributes].first[:value_text] != tempFieldValue.value_text
                PushEventJob.perform_later('additional-fields-updated', current_user, {
                  employee_name: tempUser[:first_name] + ' ' + tempUser[:last_name],
                  employee_email: tempUser[:email],
                  field_name: custom_field_params[:name],
                  value_text: custom_field_params[:custom_field_values_attributes].first[:value_text],
                  company: current_company[:name]
                })
              end
              if (custom_field_params[:custom_field_values_attributes].first[:value_text] != tempFieldValue.value_text || custom_field_params[:custom_field_values_attributes].first[:custom_field_option_id] != tempFieldValue.custom_field_option_id)
                slack_message = I18n.t('slack_notifications.custom_field.updated', field_name: custom_field_params[:name], first_name: tempUser[:first_name], last_name: tempUser[:last_name])
                history_user = tempUser
              end
            elsif tempField.section != custom_field_params[:section] ||
                  tempField.position != custom_field_params[:position] ||
                  tempField.name != custom_field_params[:name] ||
                  tempField.help_text != custom_field_params[:help_text] ||
                  tempField.default_value != custom_field_params[:default_value] ||
                  tempField.field_type != custom_field_params[:field_type] ||
                  tempField.required != custom_field_params[:required] ||
                  tempField.required_existing != custom_field_params[:required_existing] ||
                  tempField.collect_from != custom_field_params[:collect_from]
              PushEventJob.perform_later('custom-field-updated', current_user, {
                field_name: custom_field_params[:name],
                field_section: custom_field_params[:section]
              })
              slack_message = I18n.t('slack_notifications.custom_field.record_field_updated', field_name: custom_field_params[:name])
              history_description = I18n.t('history_notifications.custom_field.record_field_updated', field_name: custom_field_params[:name])
            end
          end
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: slack_message
          }) if slack_message.present?

          begin

            description =  I18n.t('history_notifications.custom_field.updated', user_first_name: current_user.first_name ,user_last_name: current_user.last_name, field_name: custom_field_params[:name], employee_first_name: tempUser.first_name, employee_last_name: tempUser.last_name )
            CreateHistoryLogJob.perform_later(current_user.id,description,tempUser.id,field_name) if field_name

          rescue Exception => e
            puts "==============================================="
            puts e

          end

          begin
            send_updates_to_integrations(field_name) if field_name.present?
            if tempUser.present?
              new_value = tempUser.get_custom_field_value_text(@custom_field.name)
              send_updates_to_webhooks(current_company, {event_type: 'custom_field', custom_field_id: @custom_field.id, old_value: old_value, new_value: new_value, user_id: tempUser.id })
            end
          rescue Exception => e
          end
        end

        def destroy
          PushEventJob.perform_later('custom-field-deleted', current_user, {
            field_name: @custom_field[:name],
            field_section: @custom_field[:section]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.custom_field.deleted', field_name: @custom_field[:name])
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t('history_notifications.custom_field.deleted', field_name: @custom_field[:name])
          })
          @custom_field.profile_template_custom_field_connections.with_deleted.delete_all
          @custom_field.destroy!
          head 204
        end

        def get_adp_wfn_fields
          adp_custom_fields = current_company.custom_fields.where(name: Integration::ADP_CUSTOM_FIELDS)
          respond_with adp_custom_fields, each_serializer: CustomFieldSerializer::WithValue, user_id: params[:user_id]
        end

        def send_updates_to_integrations(field_name)
          user = current_company.users.find_by(id: params[:user_id] || current_user.id)
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

        def get_field_name_needs_to_be_updated
          if custom_field_params[:custom_field_values_attributes].present?
            user = current_company.users.find_by(id: custom_field_params[:custom_field_values_attributes].first[:user_id])
            if user
              custom_field_value = user.custom_field_values.find_by_id(custom_field_params[:custom_field_values_attributes].first[:id]) if custom_field_params[:custom_field_values_attributes].first[:id]
            end
            value_text = custom_field_params[:custom_field_values_attributes].first[:value_text] rescue nil
            custom_field_option_id = custom_field_params[:custom_field_values_attributes].first[:custom_field_option_id] rescue nil

            if (custom_field_value.present? && ( value_text != custom_field_value.value_text || custom_field_option_id != custom_field_value.custom_field_option_id )) || (custom_field_value.blank? && (value_text.present? || custom_field_option_id.present?))
              return @custom_field.name
            end
          end

          if custom_field_params[:sub_custom_fields_attributes].present?
            custom_field_params[:sub_custom_fields_attributes].each do |key, value|
              if value[:custom_field_values_attributes].present?

                value_text = value[:custom_field_values_attributes].first[:value_text] rescue nil
                custom_field_option_id = value[:custom_field_values_attributes].first[:custom_field_option_id] rescue nil
                sub_custom_field_value = current_company.users.find_by_id(value[:custom_field_values_attributes].first[:user_id]).custom_field_values.find_by_id(value[:custom_field_values_attributes].first[:id]) if value[:custom_field_values_attributes].first[:id]

                if (sub_custom_field_value.present? && ( value_text != sub_custom_field_value.value_text || custom_field_option_id != sub_custom_field_value.custom_field_option_id )) || (sub_custom_field_value.blank? && (value_text.present? || custom_field_option_id.present?))
                  return @custom_field.name
                end
              end
            end
          end

          return nil
        end

        def delete_sub_custom_fields
          @custom_field.sub_custom_fields.delete_all
          head 204
        end

        def duplicate
          new_field = @custom_field.duplicate
          respond_with new_field, serializer: CustomFieldSerializer::WithValue
        end

        private

        def collection_params
          params.merge(company_id: current_company.id)
        end

        def custom_groups_params
          params.merge(company_id: current_company.id, integration_group: true)
        end

        def paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1 rescue 1
          params.merge(
                       sort_order: params[:sort_order],
                       sort_column: params[:sort_column],
                       page: page, per_page: params[:length])
        end

        def custom_field_params
          params.merge!(custom_field_values_attributes: [
            (params[:custom_field_value] || {}).merge(user_id: params[:user_id])
          ]) if params[:user_id]

          if params[:sub_custom_fields].present?
            params[:sub_custom_fields].each do |sub_custom_field|
              sub_custom_field.merge!(custom_field_values_attributes: [
                (sub_custom_field[:custom_field_value] || {}).merge(user_id: params[:user_id])
              ])
            end if params[:user_id]
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
            params.permit(:id, :section, :position, :name, :help_text, :field_type, :required, :required_existing, :collect_from, :is_sensitive_field, :display_location, :from_custom_group, :custom_table_id, :custom_section_id, :integration_group, :lever_requisition_field_id, :skip_validations,
            sub_custom_fields_attributes: [:id, :name, :field_type, :help_text, :_destroy, custom_field_values_attributes:
              [:id, :value_text, :user_id, :custom_field_option_id, checkbox_values: []]]).merge(company_id: current_company.id)
          else
            params.permit(:id, :section, :position, :name, :help_text, :default_value, :field_type, :required, :required_existing, :collect_from, :is_sensitive_field, :display_location, :from_custom_group, :custom_table_id, :custom_section_id, :integration_group, :lever_requisition_field_id, :skip_validations,
            custom_field_values_attributes: [:id, :value_text, :user_id, :custom_field_option_id, :sub_custom_field_id, :coworker_id, checkbox_values: []],
            custom_field_options_attributes: [:id, :option, :position, :_destroy, :description]).merge(company_id: current_company.id)
          end
        end
      end
    end
  end
end
