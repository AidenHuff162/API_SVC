module Api
  module V1
    module Admin
      class PaperworkPacketsController < BaseController
        load_and_authorize_resource 

        before_action only: [:index, :basic_index, :smart_packet_basic_index] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
        end
        before_action only: [:basic_index, :smart_packet_basic_index] do
          ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, params[:sub_tab])
        end
        before_action :authorize_user, only: [:bulk_assign]

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def index
          collection = PaperworkPacketsCollection.new(collection_params)
          respond_with collection.results, each_serializer: PaperworkPacketSerializer::Full
        end

        def basic_index
          collection = PaperworkPacketsCollection.new(collection_params)
          respond_with collection.results, each_serializer: PaperworkPacketSerializer::Basic
        end

        def smart_packet_basic_index
          collection = PaperworkPacketsCollection.new(collection_params)
          respond_with collection.results, each_serializer: DocumentPacketSerializer::Full
        end

        def paginated_index
          collection = PaperworkPacketsCollection.new(paperwork_packets_paginated_params)
          results = collection.results
          if params['document_v2']
            render json: {
              draw: params[:draw].to_i,
              recordsTotal: collection.count,
              recordsFiltered: collection.count,
              data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: DocumentPacketSerializer::Full)
            }
          else
            render json: {
              draw: params[:draw].to_i,
              recordsTotal: collection.count,
              recordsFiltered: collection.count,
              data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: PaperworkPacketSerializer::Full)
            }
          end
        end

        def show
          respond_with @paperwork_packet, serializer: PaperworkPacketSerializer::Full
        end

        def create
          save_respond_with_form
        end

        def update
          save_respond_with_form
        end

        def destroy
          users = []
          users = User.joins(:paperwork_requests).where(paperwork_requests: { paperwork_packet_id: @paperwork_packet.id}).group("users.id")
          @paperwork_packet.destroy
          users.each do |user|
            user.fix_counters
          end
          head 204
        end

        def bulk_assign
          BulkPaperworkPacketAssignmentJob.perform_later(current_company, current_user, params.to_h)
        end

        def duplicate_packet
          current_packet = @paperwork_packet
          new_packet = current_packet.dup
          pattern = "%#{new_packet.name.to_s[0,new_packet.name.length-1]}%"
          duplicate_name = new_packet.name.insert(0, 'Copy of ')
          duplicate_name = duplicate_name + " (#{current_company.paperwork_packets.where("name LIKE ?",pattern).count})"
          new_packet.name = duplicate_name
          new_packet.updated_by_id = current_user.id
          new_packet.save!

          current_packet.paperwork_packet_connections.each do |doc|
            PaperworkPacketConnection.new(
                  connectable_id: doc.connectable_id,
                  paperwork_packet_id: new_packet.id,
                  connectable_type: doc.connectable_type).save!
          end
        end

        def get_document_token
          encrypted_token = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base).encrypt_and_sign(SecureRandom.uuid + "-" + DateTime.now.to_s)
          render json: {document_token: encrypted_token}
        end

        def send_bulk_packet_email
          paperwork_request = PaperworkRequest.find_by(id: params[:paperwork_packet_request_id]) rescue nil
          return unless paperwork_request.present?
          email_data = paperwork_request.user.generate_packet_assignment_email_data(paperwork_request.document_token)
          UserMailer.document_packet_assignment_email(email_data, current_company, paperwork_request.user).deliver_now! if email_data.present?
        end

        private

        def save_respond_with_form
          if !packet_params[:paperwork_packet_connections].present? && @paperwork_packet.paperwork_packet_connections.present?
            @paperwork_packet.paperwork_packet_connections.destroy_all
          end
          paperwork_packet_params = packet_params
          paperwork_packet_params[:paperwork_packet_connections] = PaperworkPacket.exclude_duplicate_documents_in_packet(@paperwork_packet, paperwork_packet_params[:paperwork_packet_connections]) if paperwork_packet_params[:paperwork_packet_connections].present?
          form = PaperworkPacketForm.new(paperwork_packet_params)
          form.save!
          respond_with form, serializer: PaperworkPacketSerializer::Full
        end

        def packet_params
          params.merge(company_id: current_company.id, meta: params[:meta], updated_by_id: current_user.id)
        end

        def collection_params
          params.merge(company_id: current_company.id, onboarding_plan: current_company.onboarding?)
        end

        def paperwork_packets_paginated_params
          if params[:document_v2]
            sort_order = params[:sort_order]
            sort_column = params[:sort_column] 
            term = params[:term]
            page = page = (params[:start].to_i / params[:length].to_i) + 1 rescue 1
          else
            page = (params[:start].to_i / params[:length].to_i) + 1
            sort_column = params["columns"][params["order"]["0"]["column"]]["data"]
            sort_order = params["order"]["0"]["dir"]
            if sort_column == ""
              if params["order"]["0"]["column"] == "0"
                sort_column = "type"
              else params["order"]["0"]["column"] == "1"
                sort_column = "name"
              end
            end

            if params["term"]
              term = params["term"]
            elsif !params["search"]["value"].empty?
              term = params["search"]["value"]
            else
              term = nil
            end
          end

          params.merge(
            company_id: current_company.id,
            page: page,
            per_page: params[:length].to_i,
            order_column: sort_column,
            order_in: sort_order,
            term: term
          )
        end
      end
    end
  end
end
