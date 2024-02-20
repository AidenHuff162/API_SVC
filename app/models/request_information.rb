class RequestInformation < ApplicationRecord
  has_paper_trail
  # acts_as_paranoid

  belongs_to :company
  belongs_to :requester, class_name: 'User', foreign_key: :requester_id
  belongs_to :requested_to, class_name: 'User', foreign_key: :requested_to_id

  enum state: { requested: 0, pending: 1, submitted: 2 }

  validate :validate_request

  after_create :send_email_to_requested_to
  after_update :send_email_to_requester, if: Proc.new { |ri| ri.saved_change_to_state? && ri.submitted? }

  private

  def validate_request
    if self.profile_field_ids.length == 0
      errors.add(:base, I18n.t('onboard.home.dialog.profile_field_error'))
    end
  end

  def send_email_to_requested_to
    UserMailer.send_request_information_notification_to_requested_to(self).deliver_now!
    update_column(:state, RequestInformation.states[:pending])
  end

  def send_email_to_requester
    UserMailer.send_request_information_notification_to_requester(self).deliver_now!
  end
end
