module PtoRequestService
  module RestOps
    class CreateRequest < PtoRequestService::RestOps::Resource
      attr_reader :response, :current_user_id

      def initialize params, current_user_id
        @current_user_id = current_user_id
        super(params)
      end

      def perform
        request_object = create_request_with_partner_pto_requests
        request_object
      end

    end
  end
end