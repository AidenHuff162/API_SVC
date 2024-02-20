module Api
  module V1
    class CommentsController < ApiController
      before_action :require_company!
      before_action :authenticate_user!

      before_action :context

      def new
        @comment = @context.comments.new
      end

      def create
        @comment = @context.comments.new(comment_param)
        @comment.save!
        respond_with @comment, serializer: CommentSerializer::Full
      end

      def index
        respond_with @context.comments.with_deleted, each_serializer: CommentSerializer::Full
      end

      private
      def comment_param
        params.merge(company_id: current_company.id).permit(:check_for_mail, :company_id, :commenter_id, :description, :mentioned_users => [])
      end

      def context
        @context = nil
        if params[:task_user_connection_id]
          @context = TaskUserConnection.with_deleted.find_by(id: params[:task_user_connection_id])
        else params[:pto_id]
          @context = PtoRequest.with_deleted.find_by(id: params[:pto_id])
        end
      end
    end
  end
end
