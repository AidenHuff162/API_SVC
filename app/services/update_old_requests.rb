class UpdateOldRequests
  def perform
    PtoRequest.joins(:user, :pto_policy).where(pto_policies: {manager_approval: true}, status: 0).where.not(users: {manager_id: nil}).each do |pto|
      if pto.pto_policy.approval_chains.count > 0 && pto.approval_requests.count == 0 && !pto.pto_request.present?
        pto.pto_policy.approval_chains.order(id: :asc).try(:each) do |approval_chain|
          next if approval_chain.approval_type == "manager" && pto.user.manager.nil?
          pto.approval_requests.create(approval_chain_id: approval_chain.id, request_state: 'requested')
        end
      end
    end
  end
end
