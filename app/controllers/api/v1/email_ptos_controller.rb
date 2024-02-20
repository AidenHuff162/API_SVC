module Api
  module V1
    class EmailPtosController < ApiController
      before_action :require_company!
      before_action :set_pto, except: [:get_request_user]
      before_action :pto_not_valid, only: [:approve, :deny]
      before_action :can_add_comment, only: [:post_comment]

      before_action only: [:get_request_by_hash] do
        if params[:user_id].present?
          approver = User.friendly.find(params[:user_id]) rescue nil
          if approver.present? && !::PermissionService.new.can_approve_deny_pto_request(@pto_request, approver)
            raise CanCan::AccessDenied
          end
        end
      end

      def approve
        user_id = get_user_id
        pto = Pto::EmailActions.approve_pto(@pto_request, user_id)
        create_general_logging(current_company, "Approve PTO", {pto_errors: pto.errors, status: pto.status, id: params[:id]}, 'PTO')
        if pto.errors.empty?
          pto.reload
          respond_request(true, user_id, pto.hash_id, 1)
        else
          respond_request(false)
        end
      end

      def deny
        user_id = get_user_id
        pto = Pto::EmailActions.deny_pto(@pto_request, user_id)
        if pto.errors.empty?
          pto.reload
          respond_request(true, user_id, pto.hash_id, 0)
        else
          respond_request(false)
        end
      end

      def post_comment
        if params["comment"].present?
          begin
            Pto::EmailActions.add_comment(@pto_request, params["comment"], current_company.id, params[:user_id])
            respond_with status: 200
          rescue
            redirect_to get_old_pto_path
          end
        end
      end

      def get_request_by_hash
        respond_with @pto_request, serializer: PtoRequestSerializer::Email
      end

      def get_request_user
        respond_with current_company.users.where(hash_id: params[:id]).first, serializer: UserSerializer::Simple
      end
      private
      def set_pto
        begin
          @pto_request = PtoRequest.friendly.find(params[:id])
        rescue
          create_general_logging(current_company, "Approve PTO", {id: params[:id]}, 'PTO')
          redirect_to get_old_pto_path
        end
      end

      def pto_not_valid
        redirect_to get_old_pto_path if @pto_request.status != "pending" || @pto_request.pto_not_valid
      end

      def can_add_comment
        redirect_to get_old_pto_path if @pto_request.pto_not_valid
      end

      def get_user_id 
        if params[:user_id].present? 
          return params[:user_id]
        else
          manager = @pto_request.user.manager
          manager.set_hash_id if manager.hash_id.nil?
          return @pto_request.user.manager.hash_id
        end
      end

      def get_old_pto_path
        if Rails.env.development?
          return "http://#{current_company.app_domain}/#/old_pto"
        else
          return "https://#{current_company.app_domain}/#/old_pto"
        end
      end

      def respond_request(success, user_id=nil, pto_comment_id=nil, approval_type= nil)
        if params[:new_ui]
          gemini_response(success, user_id, pto_comment_id, approval_type)
        else
          legacy_response(success, user_id, pto_comment_id, approval_type)
        end
      end

      def legacy_response(success, user_id, pto_comment_id, approval_type)
        if success
          redirect_to "http#{Rails.env.production? ? 's' : ''}://#{current_company.app_domain}/#/pto_comment/#{pto_comment_id}?user_id=#{user_id}&approve=#{approval_type}"
        else
          redirect_to get_old_pto_path
        end
      end

      def gemini_response(success, user_id, pto_comment_id, approval_type)
        if success
          render json: {user_id: user_id, pto_comment_id: pto_comment_id, sucess: success, approval_type: approval_type}.to_json, status: 200
        else
          render json: {sucess: success , error: "Invalid Request"}.to_json, status: 200
        end
      end

    end
  end
end
