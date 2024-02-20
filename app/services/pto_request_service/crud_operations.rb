module PtoRequestService
  class CrudOperations
    attr_reader :params, :user, :current_user

    def initialize params = nil, user = nil, current_user =nil
      @params = params
      @user = user
      @current_user = current_user
    end

    def cancel_pto status_changed_by 
      pto_request = PtoRequest.includes(:pto_policy).find(@params[:id])
      if !can_cancel_request(pto_request)
        pto_request.errors.add(:PtoRequest, I18n.t('errors.cannot_cancel'))
        return pto_request
      end
      previous_status = pto_request.status
      unless pto_request.status == 'denied'
        partner_requests = pto_request.partner_pto_requests.to_a
        ActiveRecord::Base.transaction do
          pto_request.update(status: 3, status_changed_by: status_changed_by)
          pto_request.create_status_related_activity(@current_user.id, pto_request.status, previous_status)
        end
      else
        pto_request.errors.add(:base, I18n.t('errors.request_deniend_approved'))
      end
      pto_request
    end

    def approve_or_deny pto_request, action, current_user, email_flag = false, status_changed_by
      if !::PermissionService.new.can_approve_deny_pto_request(pto_request, current_user) || is_not_valid_person_for_approval(pto_request, current_user)
        pto_request.errors.add(:base, I18n.t('errors.cannot_approve_the_request')) if action == 1
        pto_request.errors.add(:base, I18n.t('errors.cannot_deny_the_request')) if action == 2
      else
        User.current = current_user
        old_status  = pto_request.status
        ActiveRecord::Base.transaction do
          pto_request.updated_by = current_user if (status_changed_by == 'slack' || status_changed_by == 'email')
          pto_request.status = action
          pto_request.approval_denial_date = current_user.company.time.to_date
          pto_request.email_flag = email_flag
          pto_request.status_changed_by = status_changed_by
          pto_request.save!
        end
        User.current = nil 
        pto_request.create_status_related_activity(current_user.id, action == 1 ? 'approved' : 'denied', old_status)

        message_content = {
            type: "PTO_Approval",
            pto_request: [pto_request.as_json]
        }
        SlackIntegrationJob.perform_async("PTO_Approval_Status", {user_id: pto_request.user_id, 
          current_company_id: pto_request.user.company_id, message_content: message_content})
      end
      pto_request
    end

    def can_cancel_request pto_request
      if pto_request.begin_date <= pto_request.pto_policy.company.time.to_date 
        return ::PermissionService.new.can_cancel_past_request(@current_user, pto_request)
      else
        return ::PermissionService.new.can_cancel_future_request(@current_user, pto_request)
      end
    end

    private

    def is_not_valid_person_for_approval pto_request, current_user
      return true if current_user.company != pto_request.pto_policy.company
      return false if current_user.role == "account_owner" || (current_user.role == 'admin' && current_user.id != pto_request.user_id)
      approval_chain = ApprovalRequest.current_approval_request(pto_request.id)[0]&.approval_chain
      return false if approval_chain.nil?
      if approval_chain.approval_type == "permission"
        return ::PermissionService.new.is_not_valid_person_for_approval_request_permissions(current_user, pto_request.pto_policy.company, approval_chain)
      elsif approval_chain.approval_type == "manager"
        return ::PermissionService.new.is_not_valid_person_for_approval_request_manager(current_user, pto_request, approval_chain)
      elsif approval_chain.approval_type == "person"
        return ::PermissionService.new.is_not_valid_person_for_approval_request_person(current_user, approval_chain)
      end
    end
  end
end
