module Api
  module V1
    module Admin
      class EmailTemplatesController < BaseController
        include ActionView::Helpers::SanitizeHelper
        load_and_authorize_resource
        before_action :authorize_attachments, only: [:create, :update, :send_test_email]

        before_action only: [:index] do
          if params[:offboarding]
            ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab], 'offboard_emails')
          elsif  params[:admin_onbaord_access]
            ::PermissionService.new.checkAdminVisibility(current_user, 'dashboard')
          else
            ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
          end
        end
        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
        end

        def index
          if params[:user_id]
            employee = current_company.users.find_by(id: params[:user_id]) if params[:user_id]
            params.merge!(smart_assignment: employee.smart_assignment)
            if params[:profile]
              employee.last_day_worked.present? ? params.merge!(offboarding: true, send_by_email: true) : params.merge!(onboarding: true)
            end
            collection = employee.fetch_email_templates(params.to_h)
          elsif params[:tab] == 'scheduled'
            collection = InboxEmailTemplatesCollection.new(collection_params)
          else
            user = current_company.users.find_by(id: params[:user_id]) if params[:user_id]
            collection = EmailTemplatesCollection.new(collection_params)
            if collection_params[:email_type] == "offboarding"
              user.termination_type = params[:termination_type]
              user.eligible_for_rehire = params[:eligible_for_rehire]
              user.last_day_worked = params[:last_day_worked]
              user.termination_date = params[:termination_date]
            end
          end
          respond_with collection.results.includes(:attachments, :editor), each_serializer: InboxSerializer::Simple, scope: {user: user}
        end

        def create
          @email_template.save!
          respond_with @email_template, serializer: InboxSerializer::Simple, scope: {bulk_onboarding: params[:bulk_onboarding]}
        end

        def update
          updated_email_template_params = email_template_params
          @email_template.update(updated_email_template_params)
          current_company.update_preboarding_document(params[:include_documents_preboarding]) if @email_template.email_type == "preboarding" && current_company.include_documents_preboarding != params[:include_documents_preboarding] && !params[:include_documents_preboarding].nil?
          respond_with @email_template, serializer: InboxSerializer::Simple, scope: {bulk_onboarding: params[:bulk_onboarding]}
        end

        def destroy
          @email_template.destroy
          head :no_content
        end

        def send_test_email
          Inbox::TriggerTestEmail.call(current_user, email_template_params)
          head :ok
        end

        def paginated
          collection = InboxEmailTemplatesCollection.new(paginated_params)
          user = current_company.users.find_by(id: params[:user_id])
          
          results = collection.results

          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.count,
            recordsFiltered: collection.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: InboxSerializer::Basic, scope: {user: user})
          }
        end

        def show
          respond_with @email_template, serializer: InboxSerializer::EmailTemplateSerializer
        end

        def duplicate_template
          email_template = current_company.email_templates.find_by(id: params[:id])
          new_email_template = email_template.dup
          new_email_template.is_default = false
          new_email_template.name = DuplicateNameService.call(email_template.name, current_company.email_templates)
          email_template.attachments.each do |attachment|
            file = upload_attachments(attachment)
            new_email_template.attachments.push file if file.present?
          end
          new_email_template.save
          respond_with new_email_template, serializer: InboxSerializer::Simple
        end

        def filter_templates
          respond_with current_company.email_templates.where.not(email_type: DEFAULT_NOTIFICATION_TEMPLATES).select("DISTINCT(email_type)"), each_serializer: InboxSerializer::FilterTemplateSerializer
        end

        def get_bulk_onboarding_emails
          collection = InboxEmailTemplatesCollection.new(collection_params)
          start_dates = PendingHire.where(id: params[:user_id]).pluck(:start_date)
          templates = Inbox::TemporaryEmailTemplate.new(collection, start_dates).call
          respond_with templates, each_serializer: InboxSerializer::Simple, scope: {bulk_onboarding: true}
        end

        private

        def email_template_params
          params.permit(:subject, :cc, :bcc, :description, :email_type, :email_to, :name, :invite_in, :invite_date, :editor_id, :is_enabled, :permission_type, :notifications, :is_temporary, permission_group_ids: [],
            schedule_options: [:due, :time, :date, :duration, :send_email, :relative_key, :duration_type, :to, :from, :set_onboard_cta, :time_zone], meta: {})
                .merge(company_id: current_company.id)
                .merge(attachment_ids: attachment_ids)
        end

        def collection_params
          params.merge(company_id: current_company.id)
        end

        def attachment_ids
          @attachment_ids ||= (params[:attachments] || []).map do |attachment|
            attachment[:id]
          end
        end

        def authorize_attachments
          UploadedFile::Attachment.where(id: attachment_ids).find_each do |attachment|
            authorize! :manage, attachment
          end
        end

        def paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1
          column_map = {"0": "name", "1": "modified_by", "2": "applies_to"}
          sort_column = column_map[params["order"]["0"]["column"].to_sym] rescue ""
          sort_order = params["order"]["0"]["dir"]

          if sort_column.nil?
            sort_column = "type"
          end
          params.merge(
            company_id: current_company.id,
            page: page,
            per_page: params[:length].to_i,
            order_column: sort_column,
            order_in: sort_order,
            term: params["search"]["value"].empty? ? nil : params["search"]["value"],
            current_user: current_user,
            smart_assignment: true
          )
        end

        def upload_attachments attachment
          UploadedFile.create({
            entity_type: 'EmailTemplate',
            file: attachment.file,
            type: 'UploadedFile::Attachment',
            company_id: attachment.company_id,
            original_filename: attachment.original_filename
          })
        end

        def update_meta_field email_template
          unless current_company.smart_assignment_2_feature_flag
            email_template[:meta] = {
              'location_id': params[:location_ids] || @email_template.meta['location_id'],
              'team_id': params[:department_ids] || @email_template.meta['team_id'],
              'employee_type': params[:status_ids] || @email_template.meta['employee_type']
            }
          end
          email_template
        end
      end
    end
  end
end
