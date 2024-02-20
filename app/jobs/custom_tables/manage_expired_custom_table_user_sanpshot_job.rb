module CustomTables
	class ManageExpiredCustomTableUserSanpshotJob < ApplicationJob
		queue_as :manage_expired_custom_snapshot

		def perform
			CustomTableUserSnapshot.where("requester_id IS NOT NULL AND request_state = ? AND is_applicable = ?", CustomTableUserSnapshot.request_states[:requested], true).find_each do |ctus|
				if (ctus.try(:created_at) + ctus.custom_table.try(:approval_expiry_time).days).to_date < Date.today
					ctus.activities.create(agent_id: ctus.try(:user).id, description: I18n.t("admin.people.profile_setup.roles.custom_table_user_snapshot_activities.expired_request_activity", table_name: ctus.try(:custom_table).try(:name)))
					approvers_email = ctus.approvers["approvers_emails"] rescue nil
					UserMailer.ctus_request_expired_email_notification(ctus.try(:custom_table).try(:company_id), ctus.try(:requester_id), ctus.id, ctus.try(:user_id), approvers_email).deliver_now!
					ctus.skip_dispatch_email = true
					ctus.destroy!
				end
			end
		end
	end
end
