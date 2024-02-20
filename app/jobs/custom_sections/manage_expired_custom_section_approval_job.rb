module CustomSections
  class ManageExpiredCustomSectionApprovalJob
    include Sidekiq::Worker
    sidekiq_options queue: :manage_custom_snapshots, retry: false, backtrace: true

    def perform
      CustomSectionApproval.where("requester_id IS NOT NULL AND state = ?", CustomSectionApproval.states[:requested]).find_each do |cs_approval|
        if (cs_approval.try(:created_at) + cs_approval.custom_section.try(:approval_expiry_time).to_i.days).to_date < Date.today
          approvers_email = cs_approval.approvers["approvers_emails"] rescue nil
          UserMailer.cs_approval_request_expired_email_notification(cs_approval.try(:custom_section).try(:company_id), cs_approval.try(:requester_id), cs_approval.id, cs_approval.try(:user_id), approvers_email).deliver_now!
          cs_approval.skip_dispatch_email = true
          cs_approval.destroy!
        end
      end
    end
  end
end
