module Api
  module V1
    module Admin
      class PaperworkTemplatesController < BaseController
        include HistoryHandler

        authorize_resource only: [:create, :destroy]
        load_resource except: [:index, :basic_index, :smart_basic_index, :paginated_collective_documents, :get_edit_url, :create, :destroy]
        load_and_authorize_resource only: [:finalize, :show, :update, :duplicate, :migrate_template]

        before_action only: [:index , :basic_index, :smart_basic_index] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
        end
        before_action only: [:basic_index, :smart_basic_index] do
          ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, params[:sub_tab])
        end

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def index
          collection = PaperworkTemplatesCollection.new(collection_params)
          respond_with collection.results, each_serializer: PaperworkTemplateSerializer::Full, include: "**"
        end

        def migrate_template
          response = DocumentTemplateService.new(@paperwork_template).call
          respond_with response, serializer: PaperworkTemplateSerializer::Full, include: "**"
        end

        def basic_index
          collection = PaperworkTemplatesCollection.new(collection_params)
          respond_with collection.results, each_serializer: PaperworkTemplateSerializer::Basic
        end

        def smart_basic_index
          collection = IndividualDocumentsCollection.new(documents_paginated_params)
          respond_with collection.results, each_serializer: IndividualDocumentsSerializer::Full
        end

        def paginated_collective_documents
          collection = IndividualDocumentsCollection.new(documents_paginated_params)
          results = collection.results

          meta = {
            draw: params[:draw].to_i,
            recordsTotal: collection.nil? ? 0 : collection.count,
            recordsFiltered: collection.nil? ? 0 : collection.count
          }

          render json: {
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: IndividualDocumentsSerializer::Full),
            meta: meta
          }
        end

        def paginated_collective_dashboard_documents
          collection = IndividualDocumentsDashboardCollection.new(documents_paginated_params)
          results = collection.results
          previous_results = results
          Company.current = current_company
          due_document_complete = ''

          if !documents_paginated_params['term'] && results.count == 0
            params['process_type'] = params['process_type'].downcase.eql?('overdue documents') ? 'Open Documents' : 'Overdue Documents'

            collection = IndividualDocumentsDashboardCollection.new(documents_paginated_params)
            results = collection.results

            if results.count == 0
              due_document_complete = 'All'
            end
          end

          meta = {
            draw: params[:draw].to_i,
            recordsTotal: collection.nil? ? 0 : collection.count,
            recordsFiltered: collection.nil? ? 0 : collection.count
          }
          
          render json: {
            data: ActiveModelSerializers::SerializableResource.new(due_document_complete.empty? ? previous_results : results, each_serializer: IndividualDocumentsSerializer::Dashboard, scope: {process_type: params['process_type'], company: current_company}),
            meta: meta,
            due_document_complete: due_document_complete
          }
        end

        def show
          respond_with @paperwork_template, serializer: PaperworkTemplateSerializer::Full, include: "**"
        end

        def create
          tempDoc = current_company.documents.find_by(id: paperwork_template_params[:document_id])
          paperwork_template = PaperworkTemplate.new(paperwork_template_params)
          paperwork_template.save!

          respond_with paperwork_template, serializer: PaperworkTemplateSerializer::Full, include: "**"
          execute_jobs(paperwork_template, tempDoc, 'created', 'add', 'added')
        end

        def update
          @paperwork_template.update!(template_params)
          respond_with @paperwork_template, serializer: PaperworkTemplateSerializer::Full, include: "**"
        end

        def destroy
          paperwork_template = current_company.paperwork_templates.unscoped.find_by(id: params[:id]) rescue nil

          if paperwork_template.present?
            tempDoc = current_company.documents.find_by(id: paperwork_template.document_id)
            execute_jobs(paperwork_template, tempDoc, 'deleted', 'delete', 'deleted')
            create_document_history(current_company, current_user, tempDoc.title, 'delete')
            users = User.joins(:paperwork_requests).where(paperwork_requests: {document_id: paperwork_template.document_id})
            paperwork_template.destroy

            users.each(&:fix_counters)
          end
          render body: Sapling::Application::EMPTY_BODY, status: 201
        end

        def finalize
          tempDoc = current_company.documents.find_by(id: @paperwork_template.document_id)
          @paperwork_template.finalize
          render body: Sapling::Application::EMPTY_BODY, status: 201
          PushEventJob.perform_later('paperwork-template-finalized', current_user, {
            document_name: tempDoc.title,
            template_state: @paperwork_template[:state]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t('slack_notifications.document.finalized', name: tempDoc.title)
          })
          create_document_history(current_company, current_user, tempDoc.title, 'finalize')
        end

        def get_edit_url
          begin
            response = HelloSign.get_embedded_template_edit_url(template_id: params[:hellosign_template_id], skip_signer_roles: PaperworkTemplate::SKIP_ACTION, skip_subject_message: PaperworkTemplate::SKIP_ACTION)
            respond_with :data => response.data['edit_url']
          rescue
            render json: {errors: I18n.t('errors.document_destroyed').to_s}, status: 3000
          end
        end

        def duplicate
          new_paperwork_template = @paperwork_template.duplicate_template
          respond_with new_paperwork_template, serializer: PaperworkTemplateSerializer::Full, include: "**"
          execute_jobs(new_paperwork_template, new_paperwork_template.document, 'created', 'add', 'added')
        end

        private

        def paperwork_template_params
          if params[:updated_by_id].present?
            params.permit(:document_id, :position, :representative_id, :user_id, :packet_type, :is_manager_representative).merge(company_id: current_company.id, updated_by_id: params[:updated_by_id])
          else
            params.permit(:document_id, :position, :representative_id, :user_id, :packet_type, :is_manager_representative).merge(company_id: current_company.id)
          end
        end

        def template_params
          if params[:updated_by_id].present?
            params.permit(:id, :position, :representative_id, :document_id).merge(updated_by_id: params[:updated_by_id])
          else
            params.permit(:id, :position, :representative_id, :document_id, :need_reset, :hellosign_template_id)
          end
        end

        def collection_params
          params.merge(company_id: current_company.id, state: "saved", onboarding_plan: current_company.onboarding?)
        end

        def template_paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1
          sort_column = params["columns"][params["order"]["0"]["column"]]["data"]
          sort_order = params["order"]["0"]["dir"]
          if sort_column == ""
            if params["order"]["0"]["column"] == "0"
              sort_column = "document.type"
            else params["order"]["0"]["column"] == "1"
              sort_column = "document.title"
            end
          end

          if params["term"]
            term = params["term"]
          elsif !params["search"]["value"].empty?
            term = params["search"]["value"]
          else
            term = nil
          end

          params.merge(
            company_id: current_company.id,
            state: "saved",
            page: page,
            per_page: params[:length].to_i,
            order_column: sort_column,
            order_in: sort_order,
            term: term
          )
        end

        def documents_paginated_params
          return params.merge(company_id: current_company.id) if params[:skip_pagination].present?

          page = (params[:start].to_i / params[:length].to_i) + 1 rescue 1
          params.merge(company_id: current_company.id,
                       sort_order: params[:sort_order],
                       sort_column: params[:sort_column],
                       term: params[:term], page: page,
                       per_page: params[:length])
        end

        def execute_jobs(paperwork_template, document, template_type, notifications_type, slack_notification)
          PushEventJob.perform_later("paperwork-template-#{template_type}", current_user, {
            document_name: document.title,
            template_state: paperwork_template[:state]
          })
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t("slack_notifications.document.#{slack_notification}", name: document.title)
          })
          create_document_history(current_company, current_user, document.title, "#{notifications_type}")
        end
      end
    end
  end
end
