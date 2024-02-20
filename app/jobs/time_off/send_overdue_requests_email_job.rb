module TimeOff
  class SendOverdueRequestsEmailJob < ApplicationJob
    queue_as :pto_activities

    def perform id
      request = PtoRequest.find_by_id(id)
      if request.present?
        approver = request.user.company.users.find_by(id: request.approvers["approver_ids"].compact) rescue nil
        if approver.present?
          retries ||= 0
          begin
          TimeOffMailer.send_overdue_requests_mail(request, approver).deliver_now!
          rescue Net::OpenTimeout => e
            sleep 2
            retry if (retries += 1) < 3
          end
        end
      end
    end
  end
end
