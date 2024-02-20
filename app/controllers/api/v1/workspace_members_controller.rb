module Api
  module V1
    class WorkspaceMembersController < ApiController
      before_action :authenticate_user!
      load_and_authorize_resource except: [:paginated, :get_members]
      authorize_resource only: [:paginated, :get_members]

      def paginated
        collection = WorkspaceMembersCollection.new(collection_params)
        recordsTotal = collection.results.count
        recordsTotal = recordsTotal.keys.count if recordsTotal.class == Hash
        render json: {
          draw: params[:draw].to_i,
          recordsTotal: recordsTotal,
          recordsFiltered: recordsTotal,
          data: ActiveModelSerializers::SerializableResource.new(collection.results, each_serializer: WorkspaceMemberSerializer::Short)
        }
      end

      def get_members
        collection = WorkspaceMembersCollection.new(params.merge(company_id: current_company.id, order_column: '1',  order_in: 'asc'))
        respond_with collection.results, each_serializer: WorkspaceMemberSerializer::Short
      end

      def create
        @workspace_member.save!
        WorkspaceEmailService::Invitations.new(current_user, @workspace_member.workspace, @workspace_member.member).invite_member
        respond_with @workspace_member, serializer: WorkspaceMemberSerializer::Short
      end

      def update
        @workspace_member.update!(workspace_member_params)
        respond_with @workspace_member, serializer: WorkspaceMemberSerializer::Short
      end

      def destroy
        @workspace_member.destroy!
        head 204
      end

      private

      def collection_params
        page = (params[:start].to_i / params[:length].to_i) + 1
        sort_column = params["order"]["0"]["column"]
        sort_order = params["order"]["0"]["dir"]
        params.merge(page: page, per_page: params[:length].to_i, order_column: sort_column, order_in: sort_order, company_id: current_company.id)
      end

      def workspace_member_params
        params.permit(:id, :member_role, :workspace_id, :member_id)
      end
    end
  end
end
