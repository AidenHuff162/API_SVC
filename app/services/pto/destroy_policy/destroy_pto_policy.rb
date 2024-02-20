module Pto
  module DestroyPolicy
    class DestroyPtoPolicy
      attr_reader :policy_id

      def initialize policy_id
        @pto_policy = PtoPolicy.find(policy_id)   
      end

      def perform
        delete_policy_and_associations
      end

      private

      def delete_policy_and_associations
        policy_id = @pto_policy.id
        @pto_policy.update_column(:deleted_at, @pto_policy.company.time.to_datetime)
        TimeOff::DeletePolicy.perform_later(policy_id)
        @pto_policy.reload.deleted_at.present?      
      end

    end
  end 
end