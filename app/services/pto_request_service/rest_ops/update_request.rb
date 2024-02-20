module PtoRequestService
  module RestOps
    class UpdateRequest < PtoRequestService::RestOps::Resource
      attr_reader :params, :pto_request, :current_user_id, :previous_status
      
      def initialize params, pto_request, current_user_id
        @params = params
        @pto_request = pto_request
        @current_user_id = current_user_id
        @previous_status = pto_request.status
        @request_unchanged = request_unchanged?
        params[:comments_attributes].first.merge!(check_for_mail: true) if include_comments? && @request_unchanged
        super(params, @request_unchanged, include_comments?)
      end

      def perform
        unless can_update_pto_request
          pto_request.errors.add(:base, I18n.t('errors.cannot_update_past_reqesut'))
          pto_request
        else
          if @request_unchanged
            pto_request.comments.create(params[:comments_attributes]) if include_comments?
            pto_request.attachment_ids = params[:attachment_ids]  if params[:attachment_ids].present?
            return pto_request
          else
            request_object = create_request_with_partner_pto_requests
            if request_object.errors.empty?
              PtoRequestService::Activity::CreateActivity.new(request_object, current_user_id, 'UPDATED_REQUEST',
                include_comments?, @request_unchanged, previous_status).perform 
            end
            request_object
          end
        end
      end

      private

      def request_unchanged?
        return false if pto_request.get_end_date != params["end_date"].to_date || pto_request.get_total_balance != params["balance_hours"]
        if pto_request.get_end_date == params["end_date"].to_date && pto_request.get_total_balance == params["balance_hours"]
          params.delete("end_date")
          params.delete("balance_hours")
        end
        pto_request.assign_attributes(params)
        pto_request.changes == {}
      end

      def include_comments?
        params[:comments_attributes].present? && params[:comments_attributes].size > 0
      end

      def request_consists_partner_requests?
        pto_request.partner_pto_requests.count > 0
      end

      def manage_partner_requests
        return unless request_consists_partner_requests?
        remove_partner_pto_requests
      end

      def can_update_pto_request
        return ::PermissionService.new.can_update_past_pto_request(pto_request, User.find(current_user_id), params)
      end

    end
  end
end