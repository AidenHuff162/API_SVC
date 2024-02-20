module Api
  module V1
    module Admin
      class PaperworkRequestsController < BaseController
        authorize_resource only: :create
        load_and_authorize_resource only: [:remove_draft_requests, :destroy]

        def index
          collection = PaperworkRequestsCollection.new(collection_params)
          respond_with collection.results,
          each_serializer: PaperworkRequestSerializer::WithCosigner,
          user_id: current_user.id
        end        

        def assign
          paperwork_request_ids.each do|paperwork_request_object|
            user = current_company.users.find_by(id: paperwork_request_object[:user][:id])
            if user
              begin
                request = user.paperwork_requests.find_by(id: paperwork_request_object[:id])
                id = paperwork_request_object[:id]
                if request.present?
                  request.assign
                  HellosignCall.create_signature_request_files(id, current_company.id, current_user.id)
                  request.reload
                  (request.co_signer_id? ? request.email_partially_send : request.email_completely_send) if request.email_not_sent?
                end
              rescue Exception => e
                LoggingService::GeneralLogging.new.create(current_company, 'PaperWork Request - Assign Action', {error: e.message})
              end
            end
          end
          render body: Sapling::Application::EMPTY_BODY, status: 201
        end

        def bulk_paperwork_request_assignment
          Hellosign::BulkPaperworkRequestAssignmentJob.perform_async(params[:paperwork_template_id], 
            params.to_h[:users], 
            current_user.id, 
            current_company.id, 
            params[:due_date]
          )
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def create
          if paperwork_params[:co_signer_id] == paperwork_params[:user_id]
            return render json: {errors: I18n.t('errors.different_cosigner').to_s}, status: 3000
          else
            save_respond_with_form
          end
        end

        def destroy
          @paperwork_request.destroy
          render body: Sapling::Application::EMPTY_BODY, status: 201
        end

        def remove_draft_requests
          begin
            user = current_company.users.find_by(id: params[:user_id])
            user.paperwork_requests.draft_requests.destroy_all
          rescue Exception => e
            LoggingService::GeneralLogging.new.create(current_company, 'PaperWork Request - Remove Draft Requests Action', {error: e.message})
          end
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        private

        def save_respond_with_form
          required_params = paperwork_params

          if required_params[:document_token].present?
            required_params[:document_token] = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base).decrypt_and_verify(required_params[:document_token])
          else
            required_params.merge!(document_token: SecureRandom.uuid + "-" + DateTime.now.to_s)
          end

          form = PaperworkRequestForm.new(required_params)
          form.save!
          if ((form.record.paperwork_packet_type == 'individual') || (form.record.co_signer.present? && form.record.paperwork_packet_id.present?) && !params[:smart_assignment])
            user_ids = {}
            user_ids["user_id"] = required_params["user_id"]
            user_ids["co_signer_id"] = form.record.co_signer.id if form.record.co_signer.present?
            HellosignCall.create_embedded_signature_request_with_template(user_ids, form.record.id, required_params.to_h[:page].present?, current_company.id, current_user.id)
          end
          respond_with form, serializer: PaperworkRequestSerializer::WithCosigner, include: "**"
        end

        def collection_params
          user_id = params[:user_id] || current_user.id
          params.merge(company_id: current_company.id, user_id: user_id, onboard: true)
        end

        def assign_params
          params[:paperwork_requests] || []
        end

        def paperwork_request_ids
          @paperwork_request_ids ||= assign_params.select{|request| request}
        end

        def paperwork_params
          params.merge(requester_id: current_user.id)
        end
      end
    end
  end
end
